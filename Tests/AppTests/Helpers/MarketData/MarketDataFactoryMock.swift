@testable import App
import XCTVapor

struct MarketDataFactoryMock {
    static func makeMarketData(
        currentPrice: Double = .random(in: 0.01...100_000),
        marketCap: Double = .random(in: 100_000...1_000_000_000),
        priceChange24H: Double = .random(in: -99...99)
    ) -> MarketData {
        MarketData(
            currentPrice: currentPrice,
            marketCap: marketCap,
            priceChange24H: priceChange24H
        )
    }
    
    static func makeMarketDataForCoins(ids: [String] = ["coin-1", "coin-2", "coin-3"]) -> [String: MarketData] {
        var marketDataDict: [String: MarketData] = [:]
        for id in ids {
            marketDataDict[id] = makeMarketData()
        }
        return marketDataDict
    }
}
