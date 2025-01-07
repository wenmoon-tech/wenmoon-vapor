import Fluent
import FluentPostgresDriver
import Vapor

extension CoinScannerController {
    func deleteAllCoins(on req: Request) -> EventLoopFuture<Void> {
        Coin.query(on: req.db).delete().map {
            req.logger.info("All coins deleted from the database.")
        }
    }
    
    func fetchAllCoins(
        on req: Request,
        currency: String,
        totalCoins: Int,
        perPage: Int,
        delayBetweenPages: TimeAmount = .seconds(5),
        maxRetries: Int = 10
    ) -> EventLoopFuture<Void> {
        let totalPages = Int(ceil(Double(totalCoins) / Double(perPage)))
        var currentPage = 1
        
        func fetchNextPage(retryCount: Int = .zero) -> EventLoopFuture<Void> {
            guard currentPage <= totalPages else {
                req.logger.info("Successfully fetched and updated all \(totalCoins) coins in \(currency.uppercased()) currency.")
                return req.eventLoop.makeSucceededFuture(())
            }
            return fetchCoins(on: req, currency: currency, page: currentPage, perPage: perPage)
                .flatMap { _ -> EventLoopFuture<Void> in
                    req.logger.info("Fetched page \(currentPage) of \(totalPages).")
                    currentPage += 1
                    return req.eventLoop.scheduleTask(in: delayBetweenPages) {
                        fetchNextPage()
                    }.futureResult.flatMap { $0 }
                }
                .flatMapError { error -> EventLoopFuture<Void> in
                    if retryCount < maxRetries {
                        let backoffDelay = TimeAmount.seconds(Int64(pow(2, Double(retryCount))))
                        req.logger.warning("Page \(currentPage) failed. Retrying in \(backoffDelay.nanoseconds / 1_000_000_000)s (Retry \(retryCount + 1) of \(maxRetries)).")
                        return req.eventLoop.scheduleTask(in: backoffDelay) {
                            fetchNextPage(retryCount: retryCount + 1)
                        }.futureResult.flatMap { $0 }
                    } else {
                        req.logger.error("Page \(currentPage) failed after \(maxRetries) retries. Error: \(error)")
                        return req.eventLoop.makeFailedFuture(error)
                    }
                }
        }
        return fetchNextPage()
    }
    
    private func fetchCoins(
        on req: Request,
        currency: String,
        page: Int,
        perPage: Int
    ) -> EventLoopFuture<Void> {
        guard let url = makeCoinsURL(currency: currency, page: page, perPage: perPage) else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to create URL"))
        }
        let urlRequest = makeURLRequest(url: url)
        return req.client.send(urlRequest)
            .flatMap { [weak self] response in
                guard response.status == .ok, let data = response.body else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to fetch coins: \(response.status)"))
                }
                guard let self else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Controller is nil"))
                }
                return processCoinsData(data, on: req, page: page)
            }
    }
    
    private func processCoinsData(_ data: ByteBuffer, on req: Request, page: Int) -> EventLoopFuture<Void> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let coins = try decoder.decode([Coin].self, from: Data(buffer: data))
            let dbUpserts = coins.map { coin in
                Coin.query(on: req.db)
                    .filter(\.$id == coin.id!)
                    .first()
                    .flatMap { existingCoin in
                        if let existingCoin {
                            existingCoin.updateFields(from: coin)
                            return existingCoin.update(on: req.db)
                        } else {
                            return coin.create(on: req.db)
                        }
                    }
            }
            req.logger.info("Page \(page) processed: \(coins.count) coins updated.")
            return req.eventLoop.flatten(dbUpserts).transform(to: ())
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
    
    private func makeCoinsURL(currency: String, page: Int, perPage: Int) -> URL? {
        var urlComponents = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")
        urlComponents?.queryItems = [
            URLQueryItem(name: "vs_currency", value: currency),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        return urlComponents?.url
    }
}
