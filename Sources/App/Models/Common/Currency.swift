import Foundation

enum Currency: String, Decodable {
    case usdt = "USDT"
    
    init?(rawValue: String) {
        switch rawValue {
        case "usd":
            self = .usdt
        default:
            return nil
        }
    }
}
