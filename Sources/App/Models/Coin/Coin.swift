import Fluent
import Vapor

final class Coin: Model, Content {
    static let schema = "coins"
    
    // MARK: - Properties
    @ID(custom: "id")
    var id: String?
    
    @Field(key: "symbol")
    var symbol: String
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "image")
    var image: String?
    
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
    
    @Field(key: "max_supply")
    var maxSupply: Double?
    
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
        id: String?,
        symbol: String,
        name: String,
        image: String?,
        currentPrice: Double?,
        marketCap: Double?,
        marketCapRank: Int64?,
        fullyDilutedValuation: Double?,
        totalVolume: Double?,
        high24H: Double?,
        low24H: Double?,
        priceChange24H: Double?,
        priceChangePercentage24H: Double?,
        marketCapChange24H: Double?,
        marketCapChangePercentage24H: Double?,
        circulatingSupply: Double?,
        totalSupply: Double?,
        maxSupply: Double?,
        ath: Double?,
        athChangePercentage: Double?,
        athDate: String?,
        atl: Double?,
        atlChangePercentage: Double?,
        atlDate: String?
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.image = image
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
        self.maxSupply = maxSupply
        self.ath = ath
        self.athChangePercentage = athChangePercentage
        self.athDate = athDate
        self.atl = atl
        self.atlChangePercentage = atlChangePercentage
        self.atlDate = atlDate
    }
    
    func updateFields(from newCoin: Coin) {
        symbol = newCoin.symbol
        name = newCoin.name
        image = newCoin.image
        currentPrice = newCoin.currentPrice
        marketCap = newCoin.marketCap
        marketCapRank = newCoin.marketCapRank
        fullyDilutedValuation = newCoin.fullyDilutedValuation
        totalVolume = newCoin.totalVolume
        high24H = newCoin.high24H
        low24H = newCoin.low24H
        priceChange24H = newCoin.priceChange24H
        priceChangePercentage24H = newCoin.priceChangePercentage24H
        marketCapChange24H = newCoin.marketCapChange24H
        marketCapChangePercentage24H = newCoin.marketCapChangePercentage24H
        circulatingSupply = newCoin.circulatingSupply
        totalSupply = newCoin.totalSupply
        maxSupply = newCoin.maxSupply
        ath = newCoin.ath
        athChangePercentage = newCoin.athChangePercentage
        athDate = newCoin.athDate
        atl = newCoin.atl
        atlChangePercentage = newCoin.atlChangePercentage
        atlDate = newCoin.atlDate
    }
}
