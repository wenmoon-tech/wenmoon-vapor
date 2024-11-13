import Fluent
import Vapor

struct OHLCData: Content, Decodable {
    // MARK: - Properties
    let timestamp: Int
    let close: Double
    
    // MARK: - Coding Keys
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case close
    }
    
    // MARK: - Initializers
    init(timestamp: Int, close: Double) {
        self.timestamp = timestamp
        self.close = close
    }
    
    init(from decoder: Decoder) throws {
        if var unkeyedContainer = try? decoder.unkeyedContainer() {
            timestamp = try unkeyedContainer.decode(Int.self)
            close = try unkeyedContainer.decode(Double.self)
        } else {
            let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
            timestamp = try keyedContainer.decode(Int.self, forKey: .timestamp)
            close = try keyedContainer.decode(Double.self, forKey: .close)
        }
    }
}
