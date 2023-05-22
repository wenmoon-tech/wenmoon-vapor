struct CoinMarketData: Codable {
    let currentPrice: Double?
    let priceChange: Double?

    private enum CodingKeys: String, CodingKey {
        case usd, usd24HChange
    }

    init(currentPrice: Double?, priceChange: Double?) {
        self.currentPrice = currentPrice
        self.priceChange = priceChange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPrice = try container.decodeIfPresent(Double.self, forKey: .usd)
        priceChange = try container.decodeIfPresent(Double.self, forKey: .usd24HChange)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentPrice, forKey: .usd)
        try container.encode(priceChange, forKey: .usd24HChange)
    }
}
