import Vapor

struct GlobalCryptoMarketData: Content {
    let marketCapPercentage: [String: Double]
}
