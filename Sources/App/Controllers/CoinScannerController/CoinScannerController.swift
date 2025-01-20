import Fluent
import FluentPostgresDriver
import Vapor

final class CoinScannerController {
    // MARK: - Nested Types
    struct ChartDataCache {
        var data: [Timeframe: [ChartData]]
        var lastUpdatedAt: Date
    }
    
    // MARK: - Singleton
    static let shared: CoinScannerController = .init()
    private init() {}

    // MARK: - Properties
    var chartDataCache: [String: ChartDataCache] = [:]
    var cacheTTL: [Timeframe: TimeInterval] = [
        .oneDay: 900,       // 15 minutes
        .oneWeek: 3600,     // 1 hour
        .oneMonth: 21600,   // 6 hours
        .oneYear: 86400,    // 1 day
        .all: 604800        // 1 week
    ]
    var inProgressChartDataFetches: [String: EventLoopFuture<[ChartData]>] = [:]

    // MARK: - Internal Methods
    func startFetchingCoinsPeriodically(
        app: Application,
        currency: String = "usd",
        totalCoins: Int = 250,
        perPage: Int = 250,
        coinFetchInterval: TimeAmount = .minutes(30),
        priceUpdateInterval: TimeAmount = .minutes(3),
        globalDataInterval: TimeAmount = .minutes(10)
    ) {
        let eventLoop = app.eventLoopGroup.next()
        let req = Request(application: app, on: eventLoop)
        
        var isTaskRunning = false
        
        eventLoop.scheduleRepeatedTask(initialDelay: .seconds(10), delay: coinFetchInterval) { [weak self] task in
            guard !isTaskRunning else {
                app.logger.warning("Skipped coin fetching task: Another task is running.")
                return
            }
            isTaskRunning = true
            
            self?.deleteAllCoins(on: req)
                .flatMap {
                    guard let self else {
                        return req.eventLoop.makeSucceededFuture(())
                    }
                    return self.fetchAllCoins(on: req, currency: currency, totalCoins: totalCoins, perPage: perPage)
                }
                .whenComplete { result in
                    isTaskRunning = false
                }
        }
        
        eventLoop.scheduleRepeatedTask(initialDelay: .minutes(3), delay: priceUpdateInterval) { [weak self] task in
            guard !isTaskRunning else {
                app.logger.warning("Skipped market data update task: Another task is running.")
                return
            }
            isTaskRunning = true
            self?.updateMarketData(for: currency, on: req)
                .whenComplete { result in
                    isTaskRunning = false
                }
        }
        
        eventLoop.scheduleRepeatedTask(initialDelay: .seconds(5), delay: globalDataInterval) { [weak self] task in
            guard !isTaskRunning else {
                app.logger.warning("Skipped global data fetch task: Another task is running.")
                return
            }
            isTaskRunning = true
            self?.fetchGlobalCryptoMarketData(on: req)
                .whenComplete { result in
                    isTaskRunning = false
                }
        }
    }

    func makeURLRequest(url: URL) -> ClientRequest {
        let headers = HTTPHeaders([("User-Agent", "VaporApp/1.0")])
        return ClientRequest(method: .GET, url: URI(string: url.absoluteString), headers: headers)
    }
}
