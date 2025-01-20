import Fluent
import FluentPostgresDriver
import Vapor

protocol ChartDataProvider {
    func fetchChartData(symbol: String, timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]>
}

extension CoinScannerController: ChartDataProvider {
    func fetchChartData(symbol: String, timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]> {
        let symbol = symbol.uppercased()
        let cacheKey = "\(symbol)_\(timeframe.rawValue)"
        let now = Date()
        
        if let cachedChartData = chartDataCache[cacheKey],
           let ttl = cacheTTL[timeframe],
           let chartData = cachedChartData.data[timeframe],
           now.timeIntervalSince(cachedChartData.lastUpdatedAt) < ttl {
            print("Using cached data for \(cacheKey)")
            return req.eventLoop.makeSucceededFuture(chartData)
        }
        
        let pair = mapCurrencyToPair(symbol: symbol, currency: currency)
        let process = createProcess(symbol: pair, timeframe: timeframe)
        
        let promise = req.eventLoop.makePromise(of: [ChartData].self)
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
                timeframe: timeframe,
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
    
    private func createProcess(symbol: String, timeframe: Timeframe) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["/app/ohlc_data_fetcher.py", symbol, timeframe.rawValue]
        return process
    }
    
    private func handleProcessOutput(
        _ fileHandle: FileHandle,
        for cacheKey: String,
        timeframe: Timeframe,
        promise: EventLoopPromise<[ChartData]>
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
            
            let dataToCache = [timeframe: chartData]
            chartDataCache[cacheKey] = ChartDataCache(data: dataToCache, lastUpdatedAt: Date())
            promise.succeed(chartData)
        } catch {
            promise.fail(Abort(.internalServerError, reason: "Failed to parse data from file"))
        }
    }
}
