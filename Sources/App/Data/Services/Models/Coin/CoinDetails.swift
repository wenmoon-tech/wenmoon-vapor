import Vapor

// MARK: - CoinDetails
struct CoinDetails: Content, Equatable {
    let id: String
    let marketData: MarketData
    let categories: [String]
    let publicNotice: String?
    let description: Description
    let links: Links
    let countryOrigin: String?
    let genesisDate: String?
    let sentimentVotesUpPercentage: Double?
    let sentimentVotesDownPercentage: Double?
    let watchlistPortfolioUsers: Int?
    let tickers: [Ticker]
}

// MARK: - MarketData
extension CoinDetails {
    struct MarketData: Content, Equatable {
        struct CurrencyPrice: Content, Equatable {
            let usd: Double?
        }
        
        struct CurrencyDate: Content, Equatable {
            let usd: String?
        }
        
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

// MARK: - Description
extension CoinDetails {
    struct Description: Content, Equatable {
        let en: String?
    }
}

// MARK: - Links
extension CoinDetails {
    struct Links: Content, Equatable {
        struct ReposURL: Content, Equatable {
            let github: [URL]?
        }
        
        let homepage: [URL]?
        let whitepaper: URL?
        let blockchainSite: [URL]?
        let chatUrl: [URL]?
        let announcementUrl: [URL]?
        let twitterScreenName: String?
        let telegramChannelIdentifier: String?
        let subredditUrl: URL?
        let reposUrl: ReposURL
    }
}

// MARK: - Ticker
extension CoinDetails {
    struct Ticker: Content, Equatable {
        struct Market: Content, Equatable {
            let name: String?
            let identifier: String?
            let hasTradingIncentive: Bool?
        }
        
        enum TrustScore: String, Content {
            case green, yellow, red
        }
        
        let base: String
        let target: String
        let market: Market
        let convertedLast: [String: Double]?
        let convertedVolume: [String: Double]?
        let trustScore: TrustScore?
        let tradeUrl: URL?
    }
}
