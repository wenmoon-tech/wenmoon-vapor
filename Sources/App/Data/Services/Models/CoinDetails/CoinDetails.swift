import Vapor

struct CoinDetails: Content, Equatable {
    // MARK: - Nested Types
    struct Description: Content, Equatable {
        let en: String?
    }
    
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
}
