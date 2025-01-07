import Fluent
import FluentPostgresDriver
import Vapor

extension CoinScannerController {
    func fetchGlobalCryptoMarketData(
        on req: Request,
        maxRetries: Int = 10,
        retryCount: Int = 0
    ) -> EventLoopFuture<Void> {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/global") else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to create URL"))
        }
        
        let urlRequest = makeURLRequest(url: url)
        return req.client.send(urlRequest)
            .flatMapThrowing { response -> GlobalCryptoMarketData in
                guard response.status == .ok, let data = response.body else {
                    throw Abort(.internalServerError, reason: "Failed to fetch global market data: \(response.status)")
                }
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let globalDataResponse = try decoder.decode(GlobalCryptoMarketDataResponse.self, from: Data(buffer: data))
                return GlobalCryptoMarketData(marketCapPercentage: globalDataResponse.data.marketCapPercentage)
            }
            .flatMap { newData -> EventLoopFuture<Void> in
                GlobalCryptoMarketData.query(on: req.db)
                    .first()
                    .flatMap { existingData -> EventLoopFuture<Void> in
                        if let existingData {
                            existingData.marketCapPercentage = newData.marketCapPercentage
                            return existingData.update(on: req.db)
                        } else {
                            return newData.create(on: req.db)
                        }
                    }
            }
            .flatMapError { error in
                if retryCount < maxRetries {
                    let backoffDelay = TimeAmount.seconds(Int64(pow(2, Double(retryCount))))
                    req.logger.warning("Global data fetch failed. Retrying in \(backoffDelay.nanoseconds / 1_000_000_000)s (Retry \(retryCount + 1)/\(maxRetries))")
                    return req.eventLoop.scheduleTask(in: backoffDelay) { [weak self] in
                        guard let self = self else {
                            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Self deallocated"))
                        }
                        return self.fetchGlobalCryptoMarketData(on: req, maxRetries: maxRetries, retryCount: retryCount + 1)
                    }.futureResult.flatMap { $0 }
                } else {
                    req.logger.error("Global data fetch failed after \(maxRetries) retries: \(error)")
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
    }
    
    func updateMarketData(for currency: String, on req: Request) -> EventLoopFuture<Void> {
        Coin.query(on: req.db).all().flatMap { [unowned self] coins in
            let coinBatches = stride(from: 0, to: coins.count, by: 500).map {
                Array(coins[$0..<min($0 + 500, coins.count)])
            }
            return fetchAndUpdateMarketData(for: currency, on: req, coinBatches: coinBatches, delayBetweenBatches: .seconds(2))
        }
    }
    
    private func fetchAndUpdateMarketData(
        for currency: String,
        on req: Request,
        coinBatches: [[Coin]],
        delayBetweenBatches: TimeAmount = .seconds(5),
        maxRetries: Int = 10
    ) -> EventLoopFuture<Void> {
        let eventLoop = req.eventLoop
        var currentBatchIndex = 0
        let totalBatches = coinBatches.count
        
        func processNextBatch(retryCount: Int = 0) -> EventLoopFuture<Void> {
            guard currentBatchIndex < totalBatches else {
                req.logger.info("All market data batches updated successfully.")
                return eventLoop.makeSucceededFuture(())
            }
            
            let currentBatch = coinBatches[currentBatchIndex]
            return fetchAndUpdateMarketDataBatch(currentBatch, currency: currency, on: req, maxRetries: maxRetries)
                .flatMap { _ in
                    req.logger.info("Successfully updated batch \(currentBatchIndex + 1) of \(totalBatches).")
                    currentBatchIndex += 1
                    return eventLoop.scheduleTask(in: delayBetweenBatches) {
                        processNextBatch()
                    }.futureResult.flatMap { $0 }
                }
                .flatMapError { error in
                    req.logger.error("Failed to process batch \(currentBatchIndex + 1)/\(totalBatches): \(error)")
                    return eventLoop.makeFailedFuture(error)
                }
        }
        return processNextBatch()
    }
    
    private func fetchAndUpdateMarketDataBatch(
        _ batch: [Coin],
        currency: String,
        on req: Request,
        maxRetries: Int,
        retryCount: Int = 0
    ) -> EventLoopFuture<Void> {
        let coinIDs = batch.compactMap { $0.id }.joined(separator: ",")
        guard let url = makePriceURL(ids: coinIDs, currency: currency) else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to create price URL"))
        }
        
        let urlRequest = makeURLRequest(url: url)
        return req.client.send(urlRequest)
            .flatMapThrowing { response -> [String: [String: Double]] in
                guard response.status == .ok, let data = response.body else {
                    throw Abort(.internalServerError, reason: "Failed to fetch prices: \(response.status)")
                }
                let rawMarketData = try JSONDecoder().decode([String: [String: Double?]].self, from: Data(buffer: data))
                return rawMarketData.mapValues { $0.compactMapValues { $0 } }
            }
            .flatMap { marketData in
                let updateFutures = batch.map { coin in
                    if let marketData = marketData[coin.id!] {
                        coin.currentPrice = marketData[currency]
                        coin.marketCap = marketData["\(currency)_market_cap"]
                        coin.totalVolume = marketData["\(currency)_24h_vol"]
                        coin.priceChange24H = marketData["\(currency)_24h_change"]
                        return coin.update(on: req.db)
                    }
                    return req.eventLoop.makeSucceededFuture(())
                }
                return req.eventLoop.flatten(updateFutures)
            }
            .flatMapError { error in
                if retryCount < maxRetries {
                    let backoffDelay = TimeAmount.seconds(Int64(pow(2, Double(retryCount))))
                    req.logger.warning("Market data fetch failed. Retrying in \(backoffDelay.nanoseconds / 1_000_000_000)s (Retry \(retryCount + 1)/\(maxRetries))")
                    return req.eventLoop.scheduleTask(in: backoffDelay) { [unowned self] in
                        fetchAndUpdateMarketDataBatch(batch, currency: currency, on: req, maxRetries: maxRetries, retryCount: retryCount + 1)
                    }.futureResult.flatMap { $0 }
                } else {
                    req.logger.error("Market data fetch failed after \(maxRetries) retries: \(error)")
                    return req.eventLoop.makeFailedFuture(error)
                }
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
