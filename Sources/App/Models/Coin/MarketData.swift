import Fluent
import Vapor

final class MarketData: Model, Content {
    static let schema = "market_data"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "current_price")
    var currentPrice: Double?
    
    @Field(key: "market_cap")
    var marketCap: Double?
    
    @Field(key: "total_volume")
    var totalVolume: Double?
    
    @Field(key: "price_change_percentage_24h")
    var priceChangePercentage24H: Double?
    
    init() {}

    init(
        currentPrice: Double?,
        marketCap: Double?,
        totalVolume: Double?,
        priceChangePercentage24H: Double?
    ) {
        self.currentPrice = currentPrice
        self.marketCap = marketCap
        self.totalVolume = totalVolume
        self.priceChangePercentage24H = priceChangePercentage24H
    }
}
