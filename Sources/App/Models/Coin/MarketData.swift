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
    
    init() { }

    init(currentPrice: Double?, priceChange: Double?) {
        self.currentPrice = currentPrice
        self.priceChange = priceChange
    }
    
    private enum CodingKeys: String, CodingKey {
        case currentPrice, priceChange
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let currentPrice = try container.decodeIfPresent(Double.self, forKey: .currentPrice)
        let priceChange = try container.decodeIfPresent(Double.self, forKey: .priceChange)
        self.init(currentPrice: currentPrice, priceChange: priceChange)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentPrice, forKey: .currentPrice)
        try container.encode(priceChange, forKey: .priceChange)
    }
}
