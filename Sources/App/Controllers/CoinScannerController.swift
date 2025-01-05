import Fluent
import FluentPostgresDriver
import Vapor

protocol OHLCDataProvider {
    func fetchOHLCData(symbol: String, timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[String: [OHLCData]]>
}

final class CoinScannerController: OHLCDataProvider {
    // MARK: - Nested Types
    struct OHLCDataCache {
        var data: [String: [OHLCData]]
        var lastUpdatedAt: Date
    }
    
    // MARK: - Singleton
    static let shared: CoinScannerController = .init()
    private init() {}
    
    // MARK: - Properties
    var ohlcCache: [String: OHLCDataCache] = [:]
    let cacheTTL: [Timeframe: TimeInterval] = [
        .oneHour: 60,       // 1 minute
        .oneDay: 900,       // 15 minutes
        .oneWeek: 3600,     // 1 hour
        .oneMonth: 21600,   // 6 hours
        .oneYear: 86400,    // 1 day
        .all: 604800        // 1 week
    ]
    
    // MARK: - Internal Methods
    func startFetchingCoinsPeriodically(
        app: Application,
        currency: String = "usd",
        totalCoins: Int = 1000,
        perPage: Int = 250,
        coinFetchInterval: TimeAmount = .minutes(30),
        priceUpdateInterval: TimeAmount = .minutes(3),
        globalDataInterval: TimeAmount = .minutes(10)
    ) {
        let eventLoop = app.eventLoopGroup.next()
        
        eventLoop.scheduleRepeatedTask(initialDelay: .seconds(5), delay: coinFetchInterval) { [weak self] task in
            let req = Request(application: app, on: eventLoop)
            self?.fetchAllCoins(on: req, currency: currency, totalCoins: totalCoins, perPage: perPage)
                .flatMap { _ -> EventLoopFuture<Void> in
                    app.logger.info("Successfully fetched all coins.")
                    return eventLoop.makeSucceededFuture(())
                }
                .whenFailure { error in
                    app.logger.error("Failed to update prices: \(error)")
                }
        }
        
        eventLoop.scheduleRepeatedTask(initialDelay: .minutes(3), delay: priceUpdateInterval) { [weak self] task in
            let req = Request(application: app, on: eventLoop)
            self?.updateMarketData(for: currency, on: req)
                .flatMap { _ -> EventLoopFuture<Void> in
                    app.logger.info("Successfully updated prices for all coins.")
                    return eventLoop.makeSucceededFuture(())
                }
                .whenFailure { error in
                    app.logger.error("Failed to update prices: \(error)")
                }
        }
        
        eventLoop.scheduleRepeatedTask(initialDelay: .seconds(10), delay: globalDataInterval) { [weak self] task in
            let req = Request(application: app, on: eventLoop)
            self?.fetchGlobalCryptoMarketData(on: req)
                .flatMap { globalData -> EventLoopFuture<Void> in
                    app.logger.info("Successfully fetched global market data.")
                    return eventLoop.makeSucceededFuture(())
                }
                .whenFailure { error in
                    app.logger.error("Failed to fetch global market data: \(error)")
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
        return deleteAllCoins(on: req).flatMap { [weak self] in
            let pageFetches = (1...totalPages).compactMap { page in
                self?.fetchCoins(on: req, currency: currency, page: page, perPage: perPage)
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
            .flatMap { [weak self] response in
                guard response.status == .ok, let data = response.body else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to fetch coins: \(response.status)"))
                }
                guard let self else {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Controller is nil"))
                }
                return self.processCoinsData(data, on: req, page: page)
            }
    }
    
    private func fetchGlobalCryptoMarketData(on req: Request) -> EventLoopFuture<Void> {
        guard let url = URL(string: "https://api.coingecko.com/api/v3/global") else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to create URL"))
        }
        
        let headers = HTTPHeaders([("User-Agent", "VaporApp/1.0")])
        let urlRequest = ClientRequest(method: .GET, url: URI(string: url.absoluteString), headers: headers)
        
        return req.client.send(urlRequest)
            .flatMapThrowing { response in
                guard response.status == .ok, let data = response.body else {
                    throw Abort(.internalServerError, reason: "Failed to fetch global market data: \(response.status)")
                }
                
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let globalDataResponse = try decoder.decode(GlobalCryptoMarketDataResponse.self, from: Data(buffer: data))
                let globalData = globalDataResponse.data
                
                return GlobalCryptoMarketData(marketCapPercentage: globalData.marketCapPercentage)
            }
            .flatMap { newData -> EventLoopFuture<Void> in
                GlobalCryptoMarketData.query(on: req.db)
                    .first()
                    .flatMap { existingData -> EventLoopFuture<Void> in
                        if let existingData {
                            existingData.marketCapPercentage = newData.marketCapPercentage
                            return existingData.update(on: req.db).map {
                                req.logger.info("Global market data updated in database.")
                            }
                        } else {
                            return newData.create(on: req.db).map {
                                req.logger.info("New global market data saved to database.")
                            }
                        }
                    }
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
            
            let batchFutures = coinIDBatches.map { [weak self] batch -> EventLoopFuture<Void> in
                let coinIDs = batch.compactMap { $0.id }.joined(separator: ",")
                guard let url = self?.makePriceURL(ids: coinIDs, currency: currency) else {
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
                            coin.priceChange24H = marketData["\(currency)_24h_change"]
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
    
    // MARK: - OHLCDataProvider
    func fetchOHLCData(symbol: String, timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[String: [OHLCData]]> {
        let symbol = symbol.uppercased()
        let timeframeValue = timeframe.rawValue
        let cacheKey = "\(symbol)_\(timeframeValue)"
        let now = Date()
        
        if let cachedData = ohlcCache[cacheKey],
           let ttl = cacheTTL[timeframe],
           now.timeIntervalSince(cachedData.lastUpdatedAt) < ttl {
            print("Using cached data for \(cacheKey)")
            return req.eventLoop.makeSucceededFuture(cachedData.data)
        }
        
        let pair = mapCurrencyToPair(symbol: symbol, currency: currency)
        let process = createProcess(symbol: pair, timeframe: timeframeValue)
        
        let promise = req.eventLoop.makePromise(of: [String: [OHLCData]].self)
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        do {
            try process.run()
        } catch {
            promise.fail(error)
            return promise.futureResult
        }
        
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            self?.handleProcessOutput(
                fileHandle,
                for: cacheKey,
                timeframe: timeframeValue,
                promise: promise
            )
        }
        
        return promise.futureResult
    }
    
    private func mapCurrencyToPair(symbol: String, currency: Currency) -> String {
        if symbol == "USDT" {
            return "\(symbol)/USDC"
        } else {
            return "\(symbol)/\(currency.rawValue)"
        }
    }
    
    private func createProcess(symbol: String, timeframe: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["/app/ohlc_data_fetcher.py", symbol, timeframe]
        return process
    }
    
    private func handleProcessOutput(
        _ fileHandle: FileHandle,
        for cacheKey: String,
        timeframe: String,
        promise: EventLoopPromise<[String: [OHLCData]]>
    ) {
        let data = fileHandle.availableData
        
        guard !data.isEmpty else {
            promise.fail(Abort(.internalServerError, reason: "No data received from script"))
            return
        }
        
        guard let rawOutput = String(data: data, encoding: .utf8) else {
            promise.fail(Abort(.internalServerError, reason: "Failed to convert data to String"))
            return
        }
        
        print("Raw output from script: \(rawOutput)")
        
        do {
            let fileResponse = try JSONDecoder().decode([String: String].self, from: Data(rawOutput.utf8))
            guard let filePath = fileResponse["file_path"] else {
                promise.fail(Abort(.internalServerError, reason: "File path not found in script output"))
                return
            }
            
            print("Data file path: \(filePath)")
            
            let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let ohlcResponse = try JSONDecoder().decode([[Double]].self, from: fileData)
            
            let ohlcData = ohlcResponse.compactMap { entry -> OHLCData? in
                guard entry.count == 2 else { return nil }
                return OHLCData(timestamp: Int(entry[0]), close: entry[1])
            }
            
            let response: [String: [OHLCData]] = [timeframe: ohlcData]
            ohlcCache[cacheKey] = OHLCDataCache(data: response, lastUpdatedAt: Date())
            promise.succeed(response)
        } catch {
            promise.fail(Abort(.internalServerError, reason: "Failed to parse data from file"))
        }
    }
}
