@testable import App
import Vapor
import XCTVapor

class CoinScannerServiceMock: CoinScannerService {
    // MARK: - Properties
    var fetchCoinsResult: Result<[Coin], Error>!
    var fetchCoinDetailsResult: Result<CoinDetails, Error>!
    var fetchChartDataResult: Result<[ChartData], Error>!
    var searchCoinsResult: Result<[Coin], Error>!
    var fetchMarketDataResult: Result<[String: MarketData], Error>!
    var fetchGlobalCryptoMarketDataResult: Result<GlobalCryptoMarketData, Error>!
    
    // MARK: - CoinScannerService
    func fetchCoins(onPage page: Int64, perPage: Int64, currency: Currency, req: Request) -> EventLoopFuture<[Coin]> {
        switch fetchCoinsResult {
        case .success(let coins):
            return req.eventLoop.makeSucceededFuture(coins)
        case .failure(let error):
            return req.eventLoop.makeFailedFuture(error)
        case .none:
            XCTFail("fetchCoinsResult not set")
            return fail(req: req)
        }
    }

    func fetchCoinDetails(for id: String, req: Request) -> EventLoopFuture<CoinDetails> {
        switch fetchCoinDetailsResult {
        case .success(let details):
            guard details.id == id else {
                return fail(req: req)
            }
            return req.eventLoop.makeSucceededFuture(details)
        case .failure(let error):
            return req.eventLoop.makeFailedFuture(error)
        case .none:
            XCTFail("fetchCoinDetailsResult not set")
            return fail(req: req)
        }
    }

    func fetchChartData(for id: String, on timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]> {
        switch fetchChartDataResult {
        case .success(let chartData):
            return req.eventLoop.makeSucceededFuture(chartData)
        case .failure(let error):
            return req.eventLoop.makeFailedFuture(error)
        case .none:
            XCTFail("fetchChartDataResult not set")
            return fail(req: req)
        }
    }

    func searchCoins(by query: String, req: Request) -> EventLoopFuture<[Coin]> {
        switch searchCoinsResult {
        case .success(let results):
            return req.eventLoop.makeSucceededFuture(results)
        case .failure(let error):
            return req.eventLoop.makeFailedFuture(error)
        case .none:
            XCTFail("fetchSearchResultsResult not set")
            return fail(req: req)
        }
    }

    func fetchMarketData(for ids: [String], currency: Currency, req: Request) -> EventLoopFuture<[String: MarketData]> {
        switch fetchMarketDataResult {
        case .success(let marketData):
            let filteredData = marketData.filter { ids.contains($0.key) }
            return req.eventLoop.makeSucceededFuture(filteredData)
        case .failure(let error):
            return req.eventLoop.makeFailedFuture(error)
        case .none:
            XCTFail("fetchMarketDataResult not set")
            return fail(req: req)
        }
    }

    func fetchGlobalCryptoMarketData(req: Request) -> EventLoopFuture<GlobalCryptoMarketData> {
        switch fetchGlobalCryptoMarketDataResult {
        case .success(let globalData):
            return req.eventLoop.makeSucceededFuture(globalData)
        case .failure(let error):
            return req.eventLoop.makeFailedFuture(error)
        case .none:
            XCTFail("fetchGlobalCryptoMarketDataResult not set")
            return fail(req: req)
        }
    }

    // MARK: - Private Methods
    private func fail<T>(req: Request) -> EventLoopFuture<T> {
        return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Mock service failure"))
    }
}
