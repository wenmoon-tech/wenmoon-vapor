import Vapor

extension CoinDetails {
    struct MarketData: Content, Equatable {
        // MARK: - Nested Types
        struct CurrencyPrice: Content, Equatable {
            let usd: Double?
        }
        
        struct CurrencyDate: Content, Equatable {
            let usd: String?
        }
        
        // MARK: - Properties
        let marketCapRank: Int64?
        let fullyDilutedValuation: CurrencyPrice
        let totalVolume: CurrencyPrice
        let high24H: CurrencyPrice
        let low24H: CurrencyPrice
        let marketCapChange24H: Double?
        let marketCapChangePercentage24H: Double?
        let circulatingSupply: Double?
        let totalSupply: Double?
        let maxSupply: Double?
        let ath: CurrencyPrice
        let athChangePercentage: CurrencyPrice
        let athDate: CurrencyDate
        let atl: CurrencyPrice
        let atlChangePercentage: CurrencyPrice
        let atlDate: CurrencyDate
    }
}
