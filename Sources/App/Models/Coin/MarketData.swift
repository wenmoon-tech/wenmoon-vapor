import Fluent
import Vapor

final class MarketData: Model, Content {
    static let schema = "market_data"
    
    // MARK: - Properties
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "current_price")
    var currentPrice: Double?
    
    @Field(key: "market_cap")
    var marketCap: Double?
    
    @Field(key: "market_cap_rank")
    var marketCapRank: Int64?
    
    @Field(key: "fully_diluted_valuation")
    var fullyDilutedValuation: Double?
    
    @Field(key: "total_volume")
    var totalVolume: Double?
    
    @Field(key: "high_24h")
    var high24H: Double?
    
    @Field(key: "low_24h")
    var low24H: Double?
    
    @Field(key: "price_change_24h")
    var priceChange24H: Double?
    
    @Field(key: "price_change_percentage_24h")
    var priceChangePercentage24H: Double?
    
    @Field(key: "market_cap_change_24h")
    var marketCapChange24H: Double?

    @Field(key: "market_cap_change_percentage_24h")
    var marketCapChangePercentage24H: Double?
    
    @Field(key: "circulating_supply")
    var circulatingSupply: Double?
    
    @Field(key: "total_supply")
    var totalSupply: Double?
    
    @Field(key: "ath")
    var ath: Double?
    
    @Field(key: "ath_change_percentage")
    var athChangePercentage: Double?

    @Field(key: "ath_date")
    var athDate: String?

    @Field(key: "atl")
    var atl: Double?

    @Field(key: "atl_change_percentage")
    var atlChangePercentage: Double?

    @Field(key: "atl_date")
    var atlDate: String?
    
    // MARK: - Initializers
    init() {}

    init(
        currentPrice: Double?,
        marketCap: Double?,
        marketCapRank: Int64? = nil,
        fullyDilutedValuation: Double? = nil,
        totalVolume: Double?,
        high24H: Double? = nil,
        low24H: Double? = nil,
        priceChange24H: Double?,
        priceChangePercentage24H: Double? = nil,
        marketCapChange24H: Double? = nil,
        marketCapChangePercentage24H: Double? = nil,
        circulatingSupply: Double? = nil,
        totalSupply: Double? = nil,
        ath: Double? = nil,
        athChangePercentage: Double? = nil,
        athDate: String? = nil,
        atl: Double? = nil,
        atlChangePercentage: Double? = nil,
        atlDate: String? = nil
    ) {
        self.currentPrice = currentPrice
        self.marketCap = marketCap
        self.marketCapRank = marketCapRank
        self.fullyDilutedValuation = fullyDilutedValuation
        self.totalVolume = totalVolume
        self.high24H = high24H
        self.low24H = low24H
        self.priceChange24H = priceChange24H
        self.priceChangePercentage24H = priceChangePercentage24H
        self.marketCapChange24H = marketCapChange24H
        self.marketCapChangePercentage24H = marketCapChangePercentage24H
        self.circulatingSupply = circulatingSupply
        self.totalSupply = totalSupply
        self.ath = ath
        self.athChangePercentage = athChangePercentage
        self.athDate = athDate
        self.atl = atl
        self.atlChangePercentage = atlChangePercentage
        self.atlDate = atlDate
    }
}
