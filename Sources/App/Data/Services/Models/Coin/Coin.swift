import Vapor

struct Coin: Content, Equatable {
    // MARK: - Properties
    var id: String?
    var symbol: String
    var name: String
    var image: URL?
    var currentPrice: Double?
    var marketCap: Double?
    var marketCapRank: Int64?
    var priceChange24H: Double?
    var priceChangePercentage24H: Double?
    var circulatingSupply: Double?
    var ath: Double?
    
    // MARK: - Initializer
    init(
        id: String? = nil,
        symbol: String,
        name: String,
        image: URL? = nil,
        currentPrice: Double? = nil,
        marketCap: Double? = nil,
        marketCapRank: Int64? = nil,
        priceChange24H: Double? = nil,
        priceChangePercentage24H: Double? = nil,
        circulatingSupply: Double? = nil,
        ath: Double? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.image = image
        self.currentPrice = currentPrice
        self.marketCap = marketCap
        self.marketCapRank = marketCapRank
        self.priceChange24H = priceChange24H
        self.priceChangePercentage24H = priceChangePercentage24H
        self.circulatingSupply = circulatingSupply
        self.ath = ath
    }
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image, large, currentPrice, marketCap, marketCapRank, priceChange24H, priceChangePercentage24H, circulatingSupply, ath
    }
    
    // MARK: - Decodable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        image = try container.decodeIfPresent(URL.self, forKey: .image) ?? container.decodeIfPresent(URL.self, forKey: .large)
        currentPrice = try container.decodeIfPresent(Double.self, forKey: .currentPrice)
        marketCap = try container.decodeIfPresent(Double.self, forKey: .marketCap)
        marketCapRank = try container.decodeIfPresent(Int64.self, forKey: .marketCapRank)
        priceChange24H = try container.decodeIfPresent(Double.self, forKey: .priceChange24H)
        priceChangePercentage24H = try container.decodeIfPresent(Double.self, forKey: .priceChangePercentage24H)
        circulatingSupply = try container.decodeIfPresent(Double.self, forKey: .circulatingSupply)
        ath = try container.decodeIfPresent(Double.self, forKey: .ath)
    }
    
    // MARK: - Encodable
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(image, forKey: .image)
        try container.encodeIfPresent(currentPrice, forKey: .currentPrice)
        try container.encodeIfPresent(marketCap, forKey: .marketCap)
        try container.encodeIfPresent(marketCapRank, forKey: .marketCapRank)
        try container.encodeIfPresent(priceChange24H, forKey: .priceChange24H)
        try container.encodeIfPresent(priceChangePercentage24H, forKey: .priceChangePercentage24H)
        try container.encodeIfPresent(circulatingSupply, forKey: .circulatingSupply)
        try container.encodeIfPresent(ath, forKey: .ath)
    }
}
