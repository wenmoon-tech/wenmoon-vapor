import Vapor

extension CoinDetails {
    struct Ticker: Content, Equatable {
        // MARK: - Nested Types
        struct Market: Content, Equatable {
            let name: String?
            let identifier: String?
            let hasTradingIncentive: Bool?
        }
        
        enum TrustScore: String, Content {
            case green, yellow, red
        }
        
        // MARK: - Properties
        let base: String
        let target: String
        let market: Market
        let convertedLast: [String: Double]?
        let convertedVolume: [String: Double]?
        let trustScore: TrustScore?
        let tradeUrl: URL?
        
        // MARK: - Initializer
        init(
            base: String,
            target: String,
            market: Market,
            convertedLast: [String: Double]?,
            convertedVolume: [String: Double]?,
            trustScore: TrustScore?,
            tradeUrl: URL?
        ) {
            self.base = base
            self.target = target
            self.market = market
            self.convertedLast = convertedLast
            self.convertedVolume = convertedVolume
            self.trustScore = trustScore
            self.tradeUrl = tradeUrl
        }
        
        // MARK: - Codable
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            base = try container.decode(String.self, forKey: .base)
            target = try container.decode(String.self, forKey: .target)
            market = try container.decode(Market.self, forKey: .market)
            convertedLast = try container.decodeIfPresent([String: Double].self, forKey: .convertedLast)
            convertedVolume = try container.decodeIfPresent([String: Double].self, forKey: .convertedVolume)
            trustScore = try container.decodeIfPresent(TrustScore.self, forKey: .trustScore)
            tradeUrl = container.decodeSafeURL(forKey: .tradeUrl)
        }
    }
}
