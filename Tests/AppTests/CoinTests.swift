@testable import App
import Fluent
import XCTVapor

final class CoinTests: XCTestCase {
    // MARK: - Properties
    var app: Application!
    var provider: ChartDataProviderMock!
    var headers: HTTPHeaders!
    
    // MARK: - Setup
    override func setUp() async throws {
        app = try await Application.testable()
        provider = ChartDataProviderMock()
        app.storage[ChartDataProviderKey.self] = provider
        headers = HTTPHeaders(
            [("X-API-Key", "9178693a7845b10ce1cedfe571f0682b9051aa793c41545739ce724f3ae272db")]
        )
    }
    
    override func tearDown() async throws {
        provider = nil
        try await app.autoRevert()
        try await app.asyncShutdown()
    }
    
    // MARK: - Tests
    // Get Coins
    func testGetCoins_success() async throws {
        // Setup
        let coins = try await createCoins()
        
        // Action
        try app.test(.GET, "coins", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            assertCoinsEqual(receivedCoins, coins)
        }
    }
    
    func testGetCoins_byIDs() async throws {
        // Setup
        let coin1 = try await createCoin(makeCoin(id: "coin-1", marketCapRank: 1))
        let coin2 = try await createCoin(makeCoin(id: "coin-2", marketCapRank: 2))
        let coin3 = try await createCoin(makeCoin(id: "coin-3", marketCapRank: 3))
        
        // Action
        try app.test(.GET, "coins?ids=coin-1,coin-2", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            assertCoinsEqual(receivedCoins, [coin1, coin2])
            XCTAssertFalse(receivedCoins.contains { $0.id == coin3.id })
        }
    }
    
    func testGetCoins_invalidOrEmptyIDs() async throws {
        // Setup
        _ = try await createCoin()
        
        // Action: Fetch coins with a nonexistent ID
        try app.test(.GET, "coins?ids=nonexistent-coin", headers: headers) { response in
            // Assertions: Check that no coins are returned for a nonexistent ID
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            XCTAssertTrue(receivedCoins.isEmpty)
        }
        
        // Action: Fetch coins with an empty `ids` parameter
        try app.test(.GET, "coins?ids=", headers: headers) { response in
            // Assertions: Check that no coins are returned for an empty IDs parameter
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            XCTAssertTrue(receivedCoins.isEmpty)
        }
    }
    
    func testGetCoins_pagination() async throws {
        // Setup
        let coinsAtPage1 = try await createCoins(at: 1)
        _ = try await createCoins(at: 2)
        
        // Action
        try app.test(.GET, "coins?page=1&per_page=10", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            assertCoinsEqual(receivedCoins, coinsAtPage1)
        }
    }
    
    func testGetCoins_emptyPage() async throws {
        // Setup
        _ = try await createCoin()
        
        // Action: Request page 2, which should have no results
        try app.test(.GET, "coins?page=2", headers: headers) { response in
            // Assertions: Check that page 2 returns an empty list
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            XCTAssert(receivedCoins.isEmpty)
        }
    }
    
    func testGetCoins_invalidParams() async throws {
        // Action: Request an invalid page and per_page values
        try app.test(.GET, "coins?page=-1&per_page=-1", headers: headers) { response in
            // Assertions: Check that a bad request status is returned
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Page and per_page must be positive integers"))
        }
    }
    
    // Search Coins
    func testSearchCoins_success() async throws {
        // Setup
        let coin = try await createCoin()
        
        // Action
        try app.test(.GET, "search?query=\(coin.id!)", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            assertCoinsEqual(receivedCoins, [coin])
        }
    }
    
    func testSearchCoins_emptyQuery() throws {
        // Action
        try app.test(.GET, "search?query=", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'query' is required"))
        }
    }
    
    func testSearchCoins_caseInsensitive() async throws {
        // Setup
        let coin = try await createCoin(makeCoin(id: "coin-1", name: "Coin 1"))
        
        // Action
        try app.test(.GET, "search?query=COIN", headers: headers) { response in
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            assertCoinsEqual(receivedCoins, [coin])
        }
    }
    
    // Get Market Data
    func testGetMarketData_success() async throws {
        // Setup
        let coin = try await createCoin()
        
        // Action
        try app.test(.GET, "market-data?ids=\(coin.id!)", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let marketData = try response.content.decode([String: MarketData].self)
            assertMarketDataEqual(for: [coin], with: marketData)
        }
    }
    
    func testGetMarketData_invalidOrEmptyIDs() async throws {
        // Setup
        _ = try await createCoin()
        
        // Action: Fetch market data with a nonexistent ID
        try app.test(.GET, "market-data?ids=nonexistent-coin", headers: headers) { response in
            // Assertions: Check that no market data is returned for a nonexistent ID
            XCTAssertEqual(response.status, .ok)
            let marketData = try response.content.decode([String: MarketData].self)
            XCTAssert(marketData.isEmpty)
        }
        
        // Action: Fetch market data with an empty `ids` parameter
        try app.test(.GET, "market-data?ids=", headers: headers) { response in
            // Assertions: Check that no market data is returned for an empty IDs parameter
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'ids' is required"))
        }
    }
    
    func testGetChartData_success() async throws {
        // Setup
        let chartDataForTimeframes = makeChartDataForTimeframes()
        provider.data = chartDataForTimeframes
        
        // Action
        try app.test(.GET, "chart-data?symbol=coin-1&timeframe=1d&currency=usd", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedChartData = try response.content.decode([ChartData].self)
            assertChartDataEqual(receivedChartData, chartDataForTimeframes[.oneDay]!)
        }
    }
    
    func testGetChartData_invalidOrMissingParameter() async throws {
        // Action: Make a request without the required `timeframe` query parameter
        try app.test(.GET, "chart-data?symbol=coin-1&currency=usd", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'timeframe' is invalid or missing"))
        }
        
        // Action: Make a request with an invalid value for the `currency` query parameter
        try app.test(.GET, "chart-data?symbol=coin-1&timeframe=1d&currency=invalid", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'currency' is invalid or missing"))
        }
    }
    
    func testGetChartData_emptyResponse() async throws {
        // Setup
        provider.data = [:]
        
        // Action
        try app.test(.GET, "chart-data?symbol=coin-1&timeframe=1d&currency=usd", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedChartData = try response.content.decode([ChartData].self)
            XCTAssertTrue(receivedChartData.isEmpty)
        }
    }
    
    // MARK: - Helper Methods
    // Make/Create Coin
    private func makeCoin(
        id: String = "coin-1",
        symbol: String = "c-1",
        name: String = "Coin 1",
        image: String? = nil,
        currentPrice: Double? = .random(in: 0.01...100000),
        marketCap: Double? = .random(in: 1_000_000...1_000_000_000),
        marketCapRank: Int64? = .random(in: 1...1000),
        fullyDilutedValuation: Double? = .random(in: 1_000_000...1_000_000_000),
        totalVolume: Double? = .random(in: 1000...1_000_000),
        high24H: Double? = .random(in: 0.01...100000),
        low24H: Double? = .random(in: 0.01...100000),
        priceChange24H: Double? = .random(in: -1000...1000),
        priceChangePercentage24H: Double? = .random(in: -50...50),
        marketCapChange24H: Double? = .random(in: -1_000_000...1_000_000),
        marketCapChangePercentage24H: Double? = .random(in: -50...50),
        circulatingSupply: Double? = .random(in: 1_000...1_000_000_000),
        totalSupply: Double? = .random(in: 1_000_000...1_000_000_000),
        maxSupply: Double? = .random(in: 1_000_000...1_000_000_000),
        ath: Double? = .random(in: 0.01...100000),
        athChangePercentage: Double? = .random(in: -100...100),
        athDate: String? = "2022-01-01T00:00:00.000Z",
        atl: Double? = .random(in: 0.001...10),
        atlChangePercentage: Double? = .random(in: -100...100),
        atlDate: String? = "2020-01-01T00:00:00.000Z"
    ) -> Coin {
        .init(
            id: id,
            symbol: symbol,
            name: name,
            image: image,
            currentPrice: currentPrice,
            marketCap: marketCap,
            marketCapRank: marketCapRank,
            fullyDilutedValuation: fullyDilutedValuation,
            totalVolume: totalVolume,
            high24H: high24H,
            low24H: low24H,
            priceChange24H: priceChange24H,
            priceChangePercentage24H: priceChangePercentage24H,
            marketCapChange24H: marketCapChange24H,
            marketCapChangePercentage24H: marketCapChangePercentage24H,
            circulatingSupply: circulatingSupply,
            totalSupply: totalSupply,
            maxSupply: maxSupply,
            ath: ath,
            athChangePercentage: athChangePercentage,
            athDate: athDate,
            atl: atl,
            atlChangePercentage: atlChangePercentage,
            atlDate: atlDate
        )
    }
    
    private func makeCoins(count: Int = 10, at page: Int = 1) -> [Coin] {
        let startIndex = (page - 1) * count + 1
        return (startIndex..<startIndex + count).map { index in
            makeCoin(
                id: "coin-\(index)",
                name: "Coin \(index)",
                marketCapRank: Int64(index)
            )
        }
    }
    
    private func createCoin(_ coin: Coin? = nil) async throws -> Coin {
        let coin = coin ?? makeCoin()
        try await coin.save(on: app.db)
        return coin
    }
    
    private func createCoins(count: Int = 10, at page: Int = 1) async throws -> [Coin] {
        try await makeCoins(count: count, at: page).asyncMap { coin in
            try await createCoin(coin)
        }
    }
    
    // Assertions
    private func assertCoinsEqual(_ coins: [Coin], _ expectedCoins: [Coin]) {
        XCTAssertEqual(coins.count, expectedCoins.count)
        for (index, _) in coins.enumerated() {
            let coin = coins[index]
            let expectedCoin = expectedCoins[index]
            XCTAssertEqual(coin.id, expectedCoin.id)
            XCTAssertEqual(coin.symbol, expectedCoin.symbol)
            XCTAssertEqual(coin.name, expectedCoin.name)
            XCTAssertEqual(coin.image, expectedCoin.image)
            XCTAssertEqual(coin.currentPrice, expectedCoin.currentPrice)
            XCTAssertEqual(coin.marketCap, expectedCoin.marketCap)
            XCTAssertEqual(coin.marketCapRank, expectedCoin.marketCapRank)
            XCTAssertEqual(coin.fullyDilutedValuation, expectedCoin.fullyDilutedValuation)
            XCTAssertEqual(coin.totalVolume, expectedCoin.totalVolume)
            XCTAssertEqual(coin.high24H, expectedCoin.high24H)
            XCTAssertEqual(coin.low24H, expectedCoin.low24H)
            XCTAssertEqual(coin.priceChange24H, expectedCoin.priceChange24H)
            XCTAssertEqual(coin.priceChangePercentage24H, expectedCoin.priceChangePercentage24H)
            XCTAssertEqual(coin.marketCapChange24H, expectedCoin.marketCapChange24H)
            XCTAssertEqual(coin.marketCapChangePercentage24H, expectedCoin.marketCapChangePercentage24H)
            XCTAssertEqual(coin.circulatingSupply, expectedCoin.circulatingSupply)
            XCTAssertEqual(coin.totalSupply, expectedCoin.totalSupply)
            XCTAssertEqual(coin.maxSupply, expectedCoin.maxSupply)
            XCTAssertEqual(coin.ath, expectedCoin.ath)
            XCTAssertEqual(coin.athChangePercentage, expectedCoin.athChangePercentage)
            XCTAssertEqual(coin.athDate, expectedCoin.athDate)
            XCTAssertEqual(coin.atl, expectedCoin.atl)
            XCTAssertEqual(coin.atlChangePercentage, expectedCoin.atlChangePercentage)
            XCTAssertEqual(coin.atlDate, expectedCoin.atlDate)
        }
    }
    
    private func assertMarketDataEqual(for coins: [Coin], with marketData: [String: MarketData]) {
        XCTAssertEqual(coins.count, marketData.count)
        for coin in coins {
            let expectedMarketData = marketData[coin.id!]!
            XCTAssertEqual(coin.currentPrice, expectedMarketData.currentPrice)
            XCTAssertEqual(coin.marketCap, expectedMarketData.marketCap)
            XCTAssertEqual(coin.marketCapRank, expectedMarketData.marketCapRank)
            XCTAssertEqual(coin.fullyDilutedValuation, expectedMarketData.fullyDilutedValuation)
            XCTAssertEqual(coin.totalVolume, expectedMarketData.totalVolume)
            XCTAssertEqual(coin.high24H, expectedMarketData.high24H)
            XCTAssertEqual(coin.low24H, expectedMarketData.low24H)
            XCTAssertEqual(coin.priceChange24H, expectedMarketData.priceChange24H)
            XCTAssertEqual(coin.priceChangePercentage24H, expectedMarketData.priceChangePercentage24H)
            XCTAssertEqual(coin.marketCapChange24H, expectedMarketData.marketCapChange24H)
            XCTAssertEqual(coin.marketCapChangePercentage24H, expectedMarketData.marketCapChangePercentage24H)
            XCTAssertEqual(coin.circulatingSupply, expectedMarketData.circulatingSupply)
            XCTAssertEqual(coin.totalSupply, expectedMarketData.totalSupply)
            XCTAssertEqual(coin.ath, expectedMarketData.ath)
            XCTAssertEqual(coin.athChangePercentage, expectedMarketData.athChangePercentage)
            XCTAssertEqual(coin.athDate, expectedMarketData.athDate)
            XCTAssertEqual(coin.atl, expectedMarketData.atl)
            XCTAssertEqual(coin.atlChangePercentage, expectedMarketData.atlChangePercentage)
            XCTAssertEqual(coin.atlDate, expectedMarketData.atlDate)
        }
    }
    
    // Chart Data
    private func makeChartData(
        timestamp: Int = Int(Date().timeIntervalSince1970),
        close: Double = .random(in: 1.0...100.0)
    ) -> ChartData {
        ChartData(timestamp: timestamp, close: close)
    }
    
    private func makeChartDataForTimeframes(timeframes: [Timeframe] = Timeframe.allCases) -> [Timeframe: [ChartData]] {
        var data: [Timeframe: [ChartData]] = [:]
        for timeframe in timeframes {
            data[timeframe] = (1...5).map { _ in makeChartData() }
        }
        return data
    }
    
    private func assertChartDataEqual(_ received: [ChartData], _ expected: [ChartData]) {
        XCTAssertEqual(received.count, expected.count)
        for (index, receivedData) in received.enumerated() {
            let expectedData = expected[index]
            XCTAssertEqual(receivedData.timestamp, expectedData.timestamp)
            XCTAssertEqual(receivedData.close, expectedData.close)
        }
    }
}
