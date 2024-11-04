import Fluent
import Vapor

final class Coin: Model, Content {
    static let schema = "coins"
    
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "image")
    var image: String?
    
    @Field(key: "market_cap_rank")
    var marketCapRank: Int64?
    
    @Field(key: "current_price")
    var currentPrice: Double?
    
    @Field(key: "price_change_percentage_24h")
    var priceChangePercentage24H: Double?
    
    init() {}
    
    init(
        id: String?,
        name: String,
        image: String?,
        marketCapRank: Int64?,
        currentPrice: Double?,
        priceChangePercentage24H: Double?
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.marketCapRank = marketCapRank
        self.currentPrice = currentPrice
        self.priceChangePercentage24H = priceChangePercentage24H
    }
}
