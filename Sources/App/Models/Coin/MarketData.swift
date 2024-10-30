import Fluent
import Vapor

final class MarketData: Model, Content {
    static let schema = "market_data"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "current_price")
    var currentPrice: Double?
    
    @Field(key: "price_change")
    var priceChange: Double?
    
    init() {}

    init(currentPrice: Double?, priceChange: Double?) {
        self.currentPrice = currentPrice
        self.priceChange = priceChange
    }
}
