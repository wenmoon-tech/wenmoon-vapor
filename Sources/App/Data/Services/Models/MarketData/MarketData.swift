import Vapor

struct MarketData: Content, Equatable {
    var currentPrice: Double?
    var marketCap: Double?
    var priceChange24H: Double?
}
