import Fluent
import Vapor

final class Coin: Model, Content {
    static let schema = "coins"
    
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "image_data")
    var imageData: Data?
    
    @Field(key: "market_cap_rank")
    var marketCapRank: Int64
    
    @Field(key: "current_price")
    var currentPrice: Double
    
    @Field(key: "price_change")
    var priceChange: Double
    
    init() {}
    
    init(
        id: String,
        name: String,
        imageData: Data?,
        marketCapRank: Int64,
        currentPrice: Double,
        priceChange: Double
    ) {
        self.id = id
        self.name = name
        self.imageData = imageData
        self.marketCapRank = marketCapRank
        self.currentPrice = currentPrice
        self.priceChange = priceChange
    }
}
