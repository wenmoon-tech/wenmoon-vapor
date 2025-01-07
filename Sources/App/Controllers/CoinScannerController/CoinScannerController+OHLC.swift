import Fluent
import FluentPostgresDriver
import Vapor

protocol OHLCDataProvider {
    func fetchOHLCData(symbol: String, timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[String: [OHLCData]]>
}

extension CoinScannerController: OHLCDataProvider {
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

        do {
            let fileResponse = try JSONDecoder().decode([String: String].self, from: Data(rawOutput.utf8))
            guard let filePath = fileResponse["file_path"] else {
                promise.fail(Abort(.internalServerError, reason: "File path not found in script output"))
                return
            }
            
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
