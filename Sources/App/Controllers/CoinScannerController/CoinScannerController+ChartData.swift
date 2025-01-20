import Fluent
import FluentPostgresDriver
import Vapor

protocol ChartDataProvider {
    func fetchChartDataIfNeeded(for symbol: String, on timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]>
    func fetchCachedChartData(for symbol: String, on timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]>
}

extension CoinScannerController: ChartDataProvider {
    func fetchChartDataIfNeeded(for symbol: String, on timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]> {
        if let cachedChartData = getCachedChartData(for: symbol, timeframe: timeframe) {
            return req.eventLoop.makeSucceededFuture(cachedChartData)
        }
        
        let symbol = symbol.uppercased()
        let existingFutureKey = "\(symbol)_\(timeframe.rawValue)"
        if let existingFuture = inProgressChartDataFetches[existingFutureKey] {
            return existingFuture
        }
        
        let pair = symbol == "USDT" ? "\(symbol)/USDC" : "\(symbol)/USDT"
        let process = createProcess(symbol: pair, timeframe: timeframe)
        let promise = req.eventLoop.makePromise(of: [ChartData].self)
        inProgressChartDataFetches[existingFutureKey] = promise.futureResult
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        do {
            try process.run()
        } catch {
            removeInProgressChartDataFetch(forKey: existingFutureKey)
            promise.fail(error)
            return promise.futureResult
        }
        
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            self?.handleProcessOutput(fileHandle, for: symbol, timeframe: timeframe, promise: promise)
        }
        
        return promise.futureResult.flatMap { [weak self] data in
            guard let self = self else {
                return req.eventLoop.makeSucceededFuture(data)
            }
            self.cacheChartData(data, for: symbol, timeframe: timeframe)
            self.removeInProgressChartDataFetch(forKey: existingFutureKey)
            return self.convertChartData(data, to: currency, req: req)
        }.flatMapError { [weak self] error in
            self?.removeInProgressChartDataFetch(forKey: existingFutureKey)
            return req.eventLoop.makeFailedFuture(error)
        }
    }
    
    func fetchCachedChartData(for symbol: String, on timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]> {
        guard let cachedData = getCachedChartData(for: symbol, timeframe: timeframe) else {
            return req.eventLoop.makeSucceededFuture([])
        }
        
        if currency == .usd {
            return req.eventLoop.makeSucceededFuture(cachedData)
        } else {
            return fetchConversionRate(from: .usd, to: currency, req: req).map { rate in
                cachedData.map { ChartData(timestamp: $0.timestamp, close: $0.close * rate) }
            }
        }
    }
    
    private func getCachedChartData(for symbol: String, timeframe: Timeframe) -> [ChartData]? {
        let cacheKey = "\(symbol.uppercased())_USDT"
        guard let cachedChartData = chartDataCache[cacheKey],
              let ttl = cacheTTL[timeframe],
              let chartData = cachedChartData.data[timeframe],
              Date().timeIntervalSince(cachedChartData.lastUpdatedAt) < ttl else {
            return nil
        }
        return chartData
    }
    
    private func cacheChartData(_ chartData: [ChartData], for symbol: String, timeframe: Timeframe) {
        let cacheKey = "\(symbol.uppercased())_USDT"
        if chartDataCache[cacheKey] == nil {
            chartDataCache[cacheKey] = ChartDataCache(data: [:], lastUpdatedAt: Date())
        }
        chartDataCache[cacheKey]?.data[timeframe] = chartData
        chartDataCache[cacheKey]?.lastUpdatedAt = Date()
    }
    
    private func createProcess(symbol: String, timeframe: Timeframe) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        #if DEBUG
        let scriptPath = "/Users/arturtkachenko/Desktop/Developer/wenmoon-vapor/ohlc_data_fetcher.py"
        #else
        let scriptPath = "/app/ohlc_data_fetcher.py"
        #endif
        process.arguments = [scriptPath, symbol, timeframe.rawValue]
        return process
    }
    
    private func handleProcessOutput(
        _ fileHandle: FileHandle,
        for symbol: String,
        timeframe: Timeframe,
        promise: EventLoopPromise<[ChartData]>
    ) {
        let data = fileHandle.availableData
        guard !data.isEmpty else {
            promise.fail(Abort(.internalServerError, reason: "No data received from script"))
            return
        }
        guard let rawOutput = String(data: data, encoding: .utf8) else {
            promise.fail(Abort(.internalServerError, reason: "Failed to convert data from script output"))
            return
        }
        
        do {
            let fileResponse = try JSONDecoder().decode([String: String].self, from: Data(rawOutput.utf8))
            guard let filePath = fileResponse["file_path"] else {
                promise.fail(Abort(.internalServerError, reason: "File path not found in script output"))
                return
            }
            
            let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let chartDataResponse = try JSONDecoder().decode([[Double]].self, from: fileData)
            
            let chartData = chartDataResponse.compactMap { entry -> ChartData? in
                guard entry.count == 2 else { return nil }
                return ChartData(timestamp: Int(entry[0]), close: entry[1])
            }
            
            promise.succeed(chartData)
        } catch {
            promise.fail(Abort(.internalServerError, reason: "Failed to parse data from file"))
        }
    }
    
    private func convertChartData(_ data: [ChartData], to currency: Currency, req: Request) -> EventLoopFuture<[ChartData]> {
        if currency == .usd {
            return req.eventLoop.makeSucceededFuture(data)
        } else {
            return fetchConversionRate(from: .usd, to: currency, req: req).map { rate in
                data.map { ChartData(timestamp: $0.timestamp, close: $0.close * rate) }
            }
        }
    }
    
    private func fetchConversionRate(from: Currency, to: Currency, req: Request) -> EventLoopFuture<Double> {
        // TODO: Replace with API call for real conversion rates
        let rates: [Currency: Double] = [.usd: 1, .eur: 0.85, .gbp: 0.75]
        guard let rate = rates[to] else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Unsupported currency \(to.rawValue)"))
        }
        return req.eventLoop.makeSucceededFuture(rate)
    }
    
    private func removeInProgressChartDataFetch(forKey key: String) {
        inProgressChartDataFetches.removeValue(forKey: key)
    }
}
