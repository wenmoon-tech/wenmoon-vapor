import Vapor
import Fluent

final class PriceAlert: Model, Content {
    static let schema = "price_alerts"
    
    // MARK: - Nested Types
    enum TargetDirection: String, Content {
        case above = "ABOVE"
        case below = "BELOW"
    }
    
    // MARK: - Properties
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "symbol")
    var symbol: String
    
    @Field(key: "target_price")
    var targetPrice: Double
    
    @Field(key: "target_direction")
    var targetDirection: TargetDirection
    
    @Field(key: "user_id")
    var userID: String?
    
    @Field(key: "device_token")
    var deviceToken: String?
    
    // MARK: - Initializers
    init() {}
    
    init(
        id: String?,
        symbol: String,
        targetPrice: Double,
        targetDirection: TargetDirection,
        userID: String?,
        deviceToken: String?
    ) {
        self.id = id
        self.symbol = symbol
        self.targetPrice = targetPrice
        self.targetDirection = targetDirection
        self.userID = userID
        self.deviceToken = deviceToken
    }
    
    // MARK: - Codable
    private enum CodingKeys: String, CodingKey {
        case id, symbol, targetPrice = "target_price", targetDirection = "target_direction", userID = "user_id", deviceToken = "device_token"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        targetPrice = try container.decode(Double.self, forKey: .targetPrice)
        targetDirection = try container.decode(TargetDirection.self, forKey: .targetDirection)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        deviceToken = try container.decodeIfPresent(String.self, forKey: .deviceToken)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(targetPrice, forKey: .targetPrice)
        try container.encode(targetDirection, forKey: .targetDirection)
        try container.encode(userID, forKey: .userID)
        try container.encode(deviceToken, forKey: .deviceToken)
    }
}
