import Fluent
import Vapor

final class PriceAlert: Model, Content {
    static let schema = "price_alerts"
    
    enum TargetDirection: String, Codable {
        case above = "ABOVE"
        case below = "BELOW"
    }
    
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "target_price")
    var targetPrice: Double
    
    @Field(key: "target_direction")
    var targetDirection: TargetDirection
    
    @Field(key: "device_token")
    var deviceToken: String?
    
    init() {}
    
    init(
        id: String,
        name: String,
        targetPrice: Double,
        targetDirection: TargetDirection,
        deviceToken: String?
    ) {
        self.id = id
        self.name = name
        self.targetPrice = targetPrice
        self.targetDirection = targetDirection
        self.deviceToken = deviceToken
    }
}
