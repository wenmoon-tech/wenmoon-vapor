import Vapor

struct CoinDetails: Content, Equatable {
    // MARK: - Properties
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

    // MARK: - Nested Types
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

    struct Description: Content, Equatable {
        let en: String?
    }

    struct Links: Content, Equatable {
        struct ReposURL: Content, Equatable {
            let github: [String]?
            let bitbucket: [String]?
        }

        let homepage: [String]?
        let whitepaper: String?
        let blockchainSite: [String]?
        let officialForumUrl: [String]?
        let chatUrl: [String]?
        let announcementUrl: [String]?
        let twitterScreenName: String?
        let facebookUsername: String?
        let telegramChannelIdentifier: String?
        let subredditUrl: String?
        let reposUrl: ReposURL
    }

    struct Ticker: Content, Equatable {
        struct Market: Content, Equatable {
            let name: String?
            let identifier: String?
            let hasTradingIncentive: Bool?
        }

        let base: String
        let target: String
        let market: Market
        let last: Double?
        let volume: Double?
        let convertedLast: [String: Double]?
        let convertedVolume: [String: Double]?
        let trustScore: String?
        let bidAskSpreadPercentage: Double?
        let timestamp: String?
        let lastTradedAt: String?
        let lastFetchAt: String?
        let isAnomaly: Bool?
        let isStale: Bool?
        let tradeUrl: String?
        let tokenInfoUrl: String?
        let coinId: String?
        let targetCoinId: String?
    }
}
