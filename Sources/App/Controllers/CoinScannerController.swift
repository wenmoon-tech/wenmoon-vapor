import Fluent
import FluentPostgresDriver
import Vapor

struct CoinScannerController {
    // MARK: - Singleton
    static let shared: CoinScannerController = .init()
    private init() {}
    
    // MARK: - Internal Methods
    func startFetchingCoinsPeriodically(
        app: Application,
        currency: String = "usd",
        totalCoins: Int = 1000,
        perPage: Int = 250,
        coinFetchInterval: TimeAmount = .minutes(60),
        priceUpdateInterval: TimeAmount = .minutes(3)
    ) {
        let eventLoop = app.eventLoopGroup.next()
        
        // Schedule the task for fetching and saving coins every `coinFetchInterval`
        eventLoop.scheduleRepeatedTask(initialDelay: .seconds(5), delay: coinFetchInterval) { task in
            let req = Request(application: app, on: app.eventLoopGroup.next())
            fetchAllCoins(on: req, currency: currency, totalCoins: totalCoins, perPage: perPage)
                .whenComplete { result in
                    switch result {
                    case .success:
                        app.logger.info("Successfully fetched and saved coin data.")
                    case .failure(let error):
                        app.logger.error("Failed to fetch coin data: \(error)")
                    }
                }
        }
        
        // Schedule a separate task for updating prices every `priceUpdateInterval`
        eventLoop.scheduleRepeatedTask(initialDelay: .minutes(3), delay: priceUpdateInterval) { task in
            let req = Request(application: app, on: app.eventLoopGroup.next())
            updateMarketData(for: currency, on: req)
                .whenComplete { result in
                    switch result {
                    case .success:
                        app.logger.info("Successfully updated prices for all coins.")
                    case .failure(let error):
                        app.logger.error("Failed to update prices: \(error)")
                    }
                }
        }
    }
    
    // MARK: - Private Methods
    private func fetchAllCoins(
        on req: Request,
        currency: String,
        totalCoins: Int,
        perPage: Int
    ) -> EventLoopFuture<String> {
        let totalPages = Int(ceil(Double(totalCoins) / Double(perPage)))
        return deleteAllCoins(on: req).flatMap {
            let pageFetches = (1...totalPages).map { page in
                fetchCoins(on: req, currency: currency, page: page, perPage: perPage)
            }
            return req.eventLoop.flatten(pageFetches).map {
                "Successfully fetched and updated all \(totalCoins) coins in \(currency) currency."
            }
        }
    }
    
    private func deleteAllCoins(on req: Request) -> EventLoopFuture<Void> {
        Coin.query(on: req.db).delete()
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
        
        let headers = HTTPHeaders([("User-Agent", "VaporApp/1.0")])
        let urlRequest = ClientRequest(method: .GET, url: URI(string: url.absoluteString), headers: headers)
        
        return req.client.send(urlRequest)
            .flatMap { response in
                guard response.status == .ok, let data = response.body else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to fetch coins: \(response.status)"))
                }
                return processCoinsData(data, on: req, page: page)
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
    
    private func processCoinsData(_ data: ByteBuffer, on req: Request, page: Int) -> EventLoopFuture<Void> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let coins = try decoder.decode([Coin].self, from: Data(buffer: data))
            let dbUpserts = coins.map { coin in
                return coin.create(on: req.db)
            }
            
            req.logger.info("Fetched page \(page) with \(coins.count) coins")
            return req.eventLoop.flatten(dbUpserts).transform(to: ())
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
    
    // Update Market Data
    private func updateMarketData(for currency: String, on req: Request) -> EventLoopFuture<Void> {
        Coin.query(on: req.db).all().flatMap { (coins: [Coin]) in
            let coinIDBatches = stride(from: 0, to: coins.count, by: 500).map {
                Array(coins[$0..<min($0 + 500, coins.count)])
            }
            
            let batchFutures = coinIDBatches.map { batch -> EventLoopFuture<Void> in
                let coinIDs = batch.compactMap { $0.id }.joined(separator: ",")
                guard let url = makePriceURL(ids: coinIDs, currency: currency) else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to create price URL"))
                }
                
                let headers = HTTPHeaders([("User-Agent", "VaporApp/1.0")])
                let urlRequest = ClientRequest(method: .GET, url: URI(string: url.absoluteString), headers: headers)
                
                return req.client.send(urlRequest).flatMapThrowing { response in
                    guard response.status == .ok, let data = response.body else {
                        throw Abort(.internalServerError, reason: "Failed to fetch prices: \(response.status)")
                    }
                    let rawData = try JSONDecoder().decode([String: [String: Double?]].self, from: Data(buffer: data))
                    let filteredData = rawData.mapValues { innerDict in
                        innerDict.compactMapValues { $0 }
                    }
                    return filteredData
                }
                .flatMap { marketData in
                    let updateFutures = batch.map { coin in
                        if let marketData = marketData[coin.id!] {
                            coin.currentPrice = marketData[currency]
                            coin.marketCap = marketData["\(currency)_market_cap"]
                            coin.totalVolume = marketData["\(currency)_24h_vol"]
                            coin.priceChangePercentage24H = marketData["\(currency)_24h_change"]
                            return coin.update(on: req.db)
                        }
                        return req.eventLoop.makeSucceededFuture(())
                    }
                    return req.eventLoop.flatten(updateFutures)
                }
            }
            return req.eventLoop.flatten(batchFutures)
        }
    }
    
    private func makePriceURL(ids: String, currency: String) -> URL? {
        var urlComponents = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")
        urlComponents?.queryItems = [
            URLQueryItem(name: "ids", value: ids),
            URLQueryItem(name: "vs_currencies", value: currency),
            URLQueryItem(name: "include_market_cap", value: "true"),
            URLQueryItem(name: "include_24hr_vol", value: "true"),
            URLQueryItem(name: "include_24hr_change", value: "true")
        ]
        return urlComponents?.url
    }
}
