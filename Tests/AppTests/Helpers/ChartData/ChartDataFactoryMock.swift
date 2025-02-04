@testable import App
import XCTVapor

struct ChartDataFactoryMock {
    static func makeChartData(
        timestamp: Int = Int(Date().timeIntervalSince1970),
        close: Double = .random(in: 1.0...100.0)
    ) -> ChartData {
        ChartData(timestamp: timestamp, close: close)
    }
    
    static func makeChartDataForTimeframe(timeframe: Timeframe = .oneDay) -> [ChartData] {
        (1...5).map { _ in makeChartData() }
    }
    
    static func makeChartDataForTimeframes(timeframes: [Timeframe] = Timeframe.allCases) -> [Timeframe: [ChartData]] {
        var data: [Timeframe: [ChartData]] = [:]
        for timeframe in timeframes {
            data[timeframe] = (1...5).map { _ in makeChartData() }
        }
        return data
    }
}
