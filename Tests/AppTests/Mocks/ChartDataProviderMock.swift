@testable import App
import Vapor

class ChartDataProviderMock: ChartDataProvider {
    // MARK: - Properties
    var data: [Timeframe: [ChartData]]?
    var shouldFail = false
    
    // MARK: - ChartDataProvider
    func fetchChartData(symbol: String, timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]> {
        let promise = req.eventLoop.makePromise(of: [ChartData].self)
        
        if shouldFail {
            promise.fail(Abort(.internalServerError))
        } else if let data {
            promise.succeed(data[timeframe] ?? [])
        }
        
        return promise.futureResult
    }
}
