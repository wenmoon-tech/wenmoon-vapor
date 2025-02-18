import Vapor

struct MarketData: Content, Equatable {
    let currentPrice: Double?
    let marketCap: Double?
    let priceChangePercentage24H: Double?
}
