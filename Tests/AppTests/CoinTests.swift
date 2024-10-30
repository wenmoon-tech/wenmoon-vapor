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
    func testGetCoinsSuccess() async throws {
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
    
    func testGetCoinsPaginationSuccess() async throws {
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
    
    func testGetCoinsPaginationEmpty() async throws {
        // Setup
        _ = try await createCoin()
        // Action
        try app.test(.GET, "coins?page=2") { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            XCTAssert(receivedCoins.isEmpty)
        }
    }
    
    func testGetCoinsInvalidPage() throws {
        // Action
        try app.test(.GET, "coins?page=-1") { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
        }
    }
    
    // Search Coins
    func testSearchCoinsSuccess() async throws {
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
    
    func testSearchCoinsEmptyQuery() throws {
        // Action
        try app.test(.GET, "search?query=") { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'query' is required"))
        }
    }
    
    // Get Market Data
    func testGetMarketDataSuccess() async throws {
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
    
    func testGetMarketDataMissingIDs() throws {
        // Action
        try app.test(.GET, "market-data?ids=") { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'ids' is required"))
        }
    }
    
    func testGetMarketDataWithInvalidIDs() async throws {
        // Setup
        _ = try await createCoin()
        // Action
        try app.test(.GET, "market-data?ids=nonexistentcoin") { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let marketData = try response.content.decode([String: MarketData].self)
            XCTAssert(marketData.isEmpty)
        }
    }
    
    // MARK: - Helper Methods
    // Make/Create Coin
    private func makeCoin(
        id: String = "coin-1",
        name: String = "Coin 1",
        imageData: Data? = nil,
        marketCapRank: Int64 = .random(in: 1...2500),
        currentPrice: Double = .random(in: 0.01...100000),
        priceChange: Double = .random(in: -50...50)
    ) -> Coin {
        .init(
            id: id,
            name: name,
            imageData: imageData,
            marketCapRank: marketCapRank,
            currentPrice: currentPrice,
            priceChange: priceChange
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
            XCTAssertEqual(coin.imageData, expectedCoin.imageData)
            XCTAssertEqual(coin.marketCapRank, expectedCoin.marketCapRank)
            XCTAssertEqual(coin.currentPrice, expectedCoin.currentPrice)
            XCTAssertEqual(coin.priceChange, expectedCoin.priceChange)
        }
    }
    
    private func assertMarketDataEqual(for coins: [Coin], with marketData: [String: MarketData]) {
        XCTAssertEqual(coins.count, marketData.count)
        for coin in coins {
            XCTAssertEqual(coin.currentPrice, marketData[coin.id!]!.currentPrice)
            XCTAssertEqual(coin.priceChange, marketData[coin.id!]!.priceChange)
        }
    }
}
