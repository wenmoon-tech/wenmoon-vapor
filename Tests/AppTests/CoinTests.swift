@testable import App
import Fluent
import XCTVapor

final class CoinTests: XCTestCase {
    // MARK: - Properties
    var app: Application!
    
    // MARK: - Setup
    override func setUp() async throws {
        app = try await Application.testable()
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }
    
    // MARK: - Tests
    // Get Coins
    func testGetCoins_success() async throws {
        // Setup
        let coins = try await createCoins()
        
        // Action
        try app.test(.GET, "coins") { response in
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
        try app.test(.GET, "coins?ids=coin-1,coin-2") { response in
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
        try app.test(.GET, "coins?ids=nonexistent-coin") { response in
            // Assertions: Check that no coins are returned for a nonexistent ID
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            XCTAssertTrue(receivedCoins.isEmpty)
        }
        
        // Action: Fetch coins with an empty `ids` parameter
        try app.test(.GET, "coins?ids=") { response in
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
        try app.test(.GET, "coins?page=1&per_page=10") { response in
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
        try app.test(.GET, "coins?page=2") { response in
            // Assertions: Check that page 2 returns an empty list
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            XCTAssert(receivedCoins.isEmpty)
        }
    }
    
    func testGetCoins_invalidParams() async throws {
        // Action: Request an invalid page and per_page values
        try app.test(.GET, "coins?page=-1&per_page=-1") { response in
            // Assertions: Check that a bad request status is returned
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Page and per_page must be positive integers."))
        }
    }
    
    // Search Coins
    func testSearchCoins_success() async throws {
        // Setup
        let coin = try await createCoin()
        
        // Action
        try app.test(.GET, "search?query=\(coin.id!)") { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            assertCoinsEqual(receivedCoins, [coin])
        }
    }
    
    func testSearchCoins_emptyQuery() throws {
        // Action
        try app.test(.GET, "search?query=") { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'query' is required"))
        }
    }
    
    // Get Market Data
    func testGetMarketData_success() async throws {
        // Setup
        let coin = try await createCoin()
        
        // Action
        try app.test(.GET, "market-data?ids=\(coin.id!)") { response in
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
        try app.test(.GET, "market-data?ids=nonexistent-coin") { response in
            // Assertions: Check that no market data is returned for a nonexistent ID
            XCTAssertEqual(response.status, .ok)
            let marketData = try response.content.decode([String: MarketData].self)
            XCTAssert(marketData.isEmpty)
        }
        
        // Action: Fetch market data with an empty `ids` parameter
        try app.test(.GET, "market-data?ids=") { response in
            // Assertions: Check that no market data is returned for an empty IDs parameter
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'ids' is required"))
        }
    }
    
    // MARK: - Helper Methods
    // Make/Create Coin
    private func makeCoin(
        id: String = "coin-1",
        name: String = "Coin 1",
        image: String? = nil,
        marketCapRank: Int64? = .random(in: 1...2500),
        currentPrice: Double? = .random(in: 0.01...100000),
        priceChangePercentage24H: Double? = .random(in: -50...50)
    ) -> Coin {
        .init(
            id: id,
            name: name,
            image: image,
            marketCapRank: marketCapRank,
            currentPrice: currentPrice,
            priceChangePercentage24H: priceChangePercentage24H
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
            XCTAssertEqual(coin.name, expectedCoin.name)
            XCTAssertEqual(coin.image, expectedCoin.image)
            XCTAssertEqual(coin.marketCapRank, expectedCoin.marketCapRank)
            XCTAssertEqual(coin.currentPrice, expectedCoin.currentPrice)
            XCTAssertEqual(coin.priceChangePercentage24H, expectedCoin.priceChangePercentage24H)
        }
    }
    
    private func assertMarketDataEqual(for coins: [Coin], with marketData: [String: MarketData]) {
        XCTAssertEqual(coins.count, marketData.count)
        for coin in coins {
            XCTAssertEqual(coin.currentPrice, marketData[coin.id!]!.currentPrice)
            XCTAssertEqual(coin.priceChangePercentage24H, marketData[coin.id!]!.priceChangePercentage24H)
        }
    }
}
