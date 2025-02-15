import Vapor

struct MarketData: Content, Equatable {
    let currentPrice: Double?
    let marketCap: Double?
    let priceChange24H: Double?
}
