@testable import App
import Vapor

class OHLCDataProviderMock: OHLCDataProvider {
    // MARK: - Properties
    var data: [String: [OHLCData]]?
    var shouldFail = false
    
    // MARK: - OHLCDataProvider
    func fetchOHLCData(symbol: String, currency: Currency, req: Request) -> EventLoopFuture<[String: [OHLCData]]> {
        let promise = req.eventLoop.makePromise(of: [String: [OHLCData]].self)
        
        if shouldFail {
            promise.fail(Abort(.internalServerError))
        } else if let data {
            promise.succeed(data)
        }
        
        return promise.futureResult
    }
}
