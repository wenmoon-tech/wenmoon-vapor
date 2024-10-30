import Fluent
import Vapor

final class CoinResponse: Decodable {
    let id: String
    let name: String
    let image: String?
    let marketCapRank: Int64?
    let currentPrice: Double?
    let priceChangePercentage24H: Double?
}
