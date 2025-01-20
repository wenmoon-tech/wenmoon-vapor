@testable import App
import Vapor

class ChartDataProviderMock: ChartDataProvider {
    // MARK: - Properties
    typealias ChartDataMap = [String: [Timeframe: [ChartData]]]
    
    var chartData: ChartDataMap = [:]
    var cachedChartData: ChartDataMap = [:]
    var shouldFail = false
    
    // MARK: - ChartDataProvider
    func fetchChartDataIfNeeded(
        for symbol: String,
        on timeframe: Timeframe,
        currency: Currency,
        req: Request
    ) -> EventLoopFuture<[ChartData]> {
        let eventLoop = req.eventLoop
        
        if shouldFail {
            return eventLoop.makeFailedFuture(Abort(.internalServerError))
        }
        
        if let cachedDataForTimeframe = cachedChartData[symbol]?[timeframe], !cachedDataForTimeframe.isEmpty {
            return convertData(cachedDataForTimeframe, to: currency, req: req)
        }
        
        guard let newDataForSymbol = chartData[symbol],
              let newDataForTimeframe = newDataForSymbol[timeframe] else {
            return eventLoop.makeSucceededFuture([])
        }
        
        if cachedChartData[symbol] == nil {
            cachedChartData[symbol] = newDataForSymbol
        }
        
        return convertData(newDataForTimeframe, to: currency, req: req)
    }
    
    func fetchCachedChartData(
        for symbol: String,
        on timeframe: Timeframe,
        currency: Currency,
        req: Request
    ) -> EventLoopFuture<[ChartData]> {
        let eventLoop = req.eventLoop
        
        if shouldFail {
            return eventLoop.makeFailedFuture(Abort(.internalServerError))
        }
        
        guard let cachedDataForTimeframe = cachedChartData[symbol]?[timeframe] else {
            return eventLoop.makeSucceededFuture([])
        }
        
        return convertData(cachedDataForTimeframe, to: currency, req: req)
    }
    
    // MARK: - Private Methods
    private func convertData(
        _ data: [ChartData],
        to currency: Currency,
        req: Request
    ) -> EventLoopFuture<[ChartData]> {
        let eventLoop = req.eventLoop
        
        guard currency != .usd else {
            return eventLoop.makeSucceededFuture(data)
        }
        
        return fetchConversionRate(from: .usd, to: currency, req: req).map { rate in
            data.map { ChartData(timestamp: $0.timestamp, close: $0.close * rate) }
        }
    }
    
    private func fetchConversionRate(from: Currency, to: Currency, req: Request) -> EventLoopFuture<Double> {
        req.eventLoop.makeSucceededFuture(0.9)
    }
}
