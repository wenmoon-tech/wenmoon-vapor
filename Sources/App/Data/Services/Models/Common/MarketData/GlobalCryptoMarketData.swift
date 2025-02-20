import Vapor

struct GlobalCryptoMarketData: Content, Equatable {
    let marketCapPercentage: [String: Double]
}
