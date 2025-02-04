import Vapor

struct GlobalCryptoMarketData: Content {
    var marketCapPercentage: [String: Double]
}
