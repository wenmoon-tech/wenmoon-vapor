@testable import App
import XCTVapor

struct CoinDetailsFactoryMock {
    static func makeCoinDetails(
        id: String = "coin-1",
        marketData: CoinDetails.MarketData = makeMarketData(),
        categories: [String] = ["Cryptocurrency"],
        publicNotice: String? = nil,
        description: CoinDetails.Description = makeCoinDescription(),
        links: CoinDetails.Links = makeCoinLinks(),
        countryOrigin: String? = "Global",
        genesisDate: String? = "2009-01-03",
        sentimentVotesUpPercentage: Double? = .random(in: 0...99),
        sentimentVotesDownPercentage: Double? = .random(in: 0...99),
        watchlistPortfolioUsers: Int? = .random(in: 0...1_000_000),
        tickers: [CoinDetails.Ticker] = makeCoinTickers()
    ) -> CoinDetails {
        CoinDetails(
            id: id,
            marketData: marketData,
            categories: categories,
            publicNotice: publicNotice,
            description: description,
            links: links,
            countryOrigin: countryOrigin,
            genesisDate: genesisDate,
            sentimentVotesUpPercentage: sentimentVotesUpPercentage,
            sentimentVotesDownPercentage: sentimentVotesDownPercentage,
            watchlistPortfolioUsers: watchlistPortfolioUsers,
            tickers: tickers
        )
    }
    
    static func makeMarketData() -> CoinDetails.MarketData {
        CoinDetails.MarketData(
            marketCapRank: .random(in: 1...10_000),
            fullyDilutedValuation: makeCurrencyPrice(usd: .random(in: 100_000...100_000_000_000)),
            totalVolume: makeCurrencyPrice(usd: .random(in: 100_000...100_000_000_000)),
            high24H: makeCurrencyPrice(),
            low24H: makeCurrencyPrice(),
            marketCapChange24H: .random(in: -1_000_000_000...1_000_000_000),
            marketCapChangePercentage24H: .random(in: -99...99),
            circulatingSupply: .random(in: 100_000...100_000_000_000),
            totalSupply:  .random(in: 100_000...100_000_000_000),
            maxSupply: .random(in: 100_000...100_000_000_000),
            ath: makeCurrencyPrice(),
            athChangePercentage: makeCurrencyPrice(usd: .random(in: -99...0)),
            athDate: makeCurrencyDate(),
            atl: makeCurrencyPrice(),
            atlChangePercentage: makeCurrencyPrice(usd: .random(in: 0...99)),
            atlDate: makeCurrencyDate()
        )
    }
    
    static func makeCurrencyPrice(usd: Double = .random(in: 0.01...100_000)) -> CoinDetails.MarketData.CurrencyPrice {
        CoinDetails.MarketData.CurrencyPrice(usd: usd)
    }
    
    static func makeCurrencyDate(usd: String = "2013-07-06T00:00:00Z") -> CoinDetails.MarketData.CurrencyDate {
        CoinDetails.MarketData.CurrencyDate(usd: usd)
    }
    
    static func makeCoinDescription() -> CoinDetails.Description {
        CoinDetails.Description(
            en: "Bitcoin is the first decentralized digital currency, created in 2009 by Satoshi Nakamoto."
        )
    }
    
    static func makeCoinLinks() -> CoinDetails.Links {
        CoinDetails.Links(
            homepage: ["https://bitcoin.org"],
            whitepaper: "https://bitcoin.org/bitcoin.pdf",
            blockchainSite: ["https://www.blockchain.com/explorer"],
            officialForumURL: ["https://bitcointalk.org"],
            chatURL: ["https://discord.com/invite/bitcoin"],
            announcementURL: ["https://twitter.com/bitcoin"],
            twitterScreenName: "bitcoin",
            facebookUsername: "bitcoin",
            telegramChannelIdentifier: "bitcoin",
            subredditURL: "https://www.reddit.com/r/bitcoin/",
            reposUrl: makeReposURL()
        )
    }
    
    static func makeReposURL() -> CoinDetails.Links.ReposURL {
        CoinDetails.Links.ReposURL(
            github: ["https://github.com/bitcoin"],
            bitbucket: nil
        )
    }
    
    static func makeCoinTickers() -> [CoinDetails.Ticker] {
        [
            CoinDetails.Ticker(
                base: "BTC",
                target: "USD",
                market: CoinDetails.Ticker.Market(
                    name: "Binance",
                    identifier: "binance",
                    hasTradingIncentive: false
                ),
                last: .random(in: 0.01...100_000),
                volume: .random(in: 100_000...100_000_000),
                convertedLast: ["usd": .random(in: 0.01...100_000)],
                convertedVolume: ["usd": .random(in: 100_000...100_000_000)],
                trustScore: "green",
                bidAskSpreadPercentage: .random(in: 0.01...10),
                timestamp: "2024-02-05T12:00:00Z",
                lastTradedAt: "2024-02-05T12:00:00Z",
                lastFetchAt: "2024-02-05T12:00:00Z",
                isAnomaly: false,
                isStale: false,
                tradeURL: "https://binance.com/trade/BTC_USD",
                tokenInfoURL: nil,
                coinId: "bitcoin",
                targetCoinId: "usd"
            )
        ]
    }
}
