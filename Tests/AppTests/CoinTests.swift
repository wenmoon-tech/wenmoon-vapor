@testable import App
import Fluent
import XCTVapor

final class CoinTests: XCTestCase {
    // MARK: - Properties
    var app: Application!
    var service: CoinScannerServiceMock!
    var headers: HTTPHeaders!
    
    // MARK: - Setup
    override func setUp() async throws {
        app = try await Application.testable()
        service = CoinScannerServiceMock()
        app.storage[CoinInfoProviderKey.self] = service
        headers = HTTPHeaders(
            [("X-API-Key", "9178693a7845b10ce1cedfe571f0682b9051aa793c41545739ce724f3ae272db")]
        )
    }
    
    override func tearDown() async throws {
        service = nil
        try await app.autoRevert()
        try await app.asyncShutdown()
    }
    
    // MARK: - Tests
    // Coins
    func testGetCoins_pagination() async throws {
        // Setup
        let coins = CoinFactoryMock.makeCoins(at: 1)
        service.fetchCoinsResult = .success(coins)
        
        // Action
        try app.test(.GET, "coins?page=1&per_page=10", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            assertCoinsEqual(receivedCoins, coins)
        }
    }
    
    func testGetCoins_emptyPage() async throws {
        // Setup
        service.fetchCoinsResult = .success([])
        
        // Action: Request page 2, which should have no results
        try app.test(.GET, "coins?page=2", headers: headers) { response in
            // Assertions: Check that page 2 returns an empty list
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            XCTAssert(receivedCoins.isEmpty)
        }
    }
    
    // Coin Details
    func testGetCoinDetails_success() async throws {
        // Setup
        let coinDetails = CoinDetailsFactoryMock.makeCoinDetails()
        service.fetchCoinDetailsResult = .success(coinDetails)
        
        // Action
        try app.test(.GET, "coin-details?id=\(coinDetails.id)", headers: headers) { response in
            XCTAssertEqual(response.status, .ok)
            let receivedCoinDetails = try response.content.decode(CoinDetails.self)
            XCTAssertEqual(receivedCoinDetails, coinDetails)
        }
    }
    
    func testGetCoinDetails_invalidOrMissingID() async throws {
        // Setup
        let coinDetails = CoinDetailsFactoryMock.makeCoinDetails()
        service.fetchCoinDetailsResult = .success(coinDetails)
        
        
        // Action: Fetch coin details with a nonexistent ID
        try app.test(.GET, "coin-details?id=nonexistent-coin", headers: headers) { response in
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Mock service failure"))
        }
        
        // Action: Fetch coin details with missing `id` parameter
        try app.test(.GET, "coin-details", headers: headers) { response in
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'id' is required"))
        }
    }
    
    // Chart Data
    func testGetChartData_success() async throws {
        // Setup
        let symbol = "C-1"
        let chartData = ChartDataFactoryMock.makeChartDataForTimeframe()
        service.fetchChartDataResult = .success(chartData)
        
        // Action
        try app.test(.GET, "chart-data?id=\(symbol)&timeframe=1&currency=usd", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedChartData = try response.content.decode([ChartData].self)
            assertChartDataEqual(receivedChartData, chartData)
        }
    }
    
    func testGetChartData_invalidOrMissingParameter() async throws {
        // Action: Make a request without the required `timeframe` query parameter
        try app.test(.GET, "chart-data?timeframe=1&currency=usd", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'id' is invalid or missing"))
        }
        
        // Action: Make a request with an invalid value for the `timeframe` query parameter
        try app.test(.GET, "chart-data?id=coin-1&currency=usd", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'timeframe' is invalid or missing"))
        }
        
        // Action: Make a request with an invalid value for the `currency` query parameter
        try app.test(.GET, "chart-data?id=coin-1&timeframe=1&currency=invalid", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'currency' is invalid or missing"))
        }
    }
    
    func testGetChartData_emptyResponse() async throws {
        // Setup
        service.fetchChartDataResult = .success([])
        
        // Action
        try app.test(.GET, "chart-data?id=coin-1&timeframe=1&currency=usd", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedChartData = try response.content.decode([ChartData].self)
            XCTAssertTrue(receivedChartData.isEmpty)
        }
    }
    
    // Search Coins
    func testSearchCoins_success() async throws {
        // Setup
        let coins = CoinFactoryMock.makeCoins()
        service.searchCoinsResult = .success(coins)
        
        // Action
        try app.test(.GET, "search?query=coin", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            assertCoinsEqual(receivedCoins, coins)
        }
    }
    
    func testSearchCoins_emptyQuery() throws {
        // Action
        try app.test(.GET, "search", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'query' is required"))
        }
    }
    
    func testSearchCoins_caseInsensitive() async throws {
        // Setup
        let coins = CoinFactoryMock.makeCoins()
        service.searchCoinsResult = .success(coins)
        
        // Action
        try app.test(.GET, "search?query=COIN", headers: headers) { response in
            XCTAssertEqual(response.status, .ok)
            let receivedCoins = try response.content.decode([Coin].self)
            assertCoinsEqual(receivedCoins, coins)
        }
    }
    
    // Market Data
    func testGetMarketData_success() async throws {
        // Setup
        let marketData = MarketDataFactoryMock.makeMarketDataForCoins()
        service.fetchMarketDataResult = .success(marketData)
        
        // Action
        try app.test(.GET, "market-data?ids=coin-1,coin-2,coin-3", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedMarketData = try response.content.decode([String: MarketData].self)
            assertMarketDataEqual(receivedMarketData, marketData)
        }
    }
    
    func testGetMarketData_invalidOrMissingIDs() async throws {
        // Setup
        let marketData = MarketDataFactoryMock.makeMarketDataForCoins()
        service.fetchMarketDataResult = .success(marketData)
        
        // Action: Fetch market data with a nonexistent ID
        try app.test(.GET, "market-data?ids=nonexistent-coin", headers: headers) { response in
            // Assertions: Check that no market data is returned for a nonexistent ID
            XCTAssertEqual(response.status, .ok)
            let receivedMarketData = try response.content.decode([String: MarketData].self)
            XCTAssert(receivedMarketData.isEmpty)
        }
        
        // Action: Fetch market data with missing `ids` parameter
        try app.test(.GET, "market-data", headers: headers) { response in
            // Assertions: Check that no market data is returned for missing IDs parameter
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains("Query parameter 'ids' is required"))
        }
    }
    
    // Global Market Data
    func testGetFearAndGreedIndex_success() async throws {
        // Setup
        let index = FearAndGreedIndex(data: [.init(value: "75", valueClassification: "Greed")])
        service.fetchFearAndGreedIndexResult = .success(index)
        
        // Action
        try app.test(.GET, "fear-and-greed", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedIndex = try response.content.decode(FearAndGreedIndex.self)
            XCTAssertEqual(receivedIndex, index)
        }
    }
    
    func testGetFearAndGreed_failure() async throws {
        // Setup
        let reason = "Mock service failure"
        service.fetchFearAndGreedIndexResult = .failure(Abort(.internalServerError, reason: reason))
        
        // Action
        try app.test(.GET, "fear-and-greed", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .internalServerError)
            XCTAssert(response.body.string.contains(reason))
        }
    }
    
    func testGetGlobalCryptoMarketData_success() async throws {
        // Setup
        let data = GlobalCryptoMarketData(
            marketCapPercentage: [
                "btc": 57.83,
                "eth": 13.47,
                "usdt": 2.62
            ]
        )
        service.fetchGlobalCryptoMarketDataResult = .success(data)
        
        // Action
        try app.test(.GET, "global-crypto-market-data", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedData = try response.content.decode(GlobalCryptoMarketData.self)
            XCTAssertEqual(receivedData, data)
        }
    }
    
    func testGetGlobalCryptoMarketData_serviceFailure() async throws {
        // Setup
        let reason = "Mock service failure"
        service.fetchGlobalCryptoMarketDataResult = .failure(Abort(.internalServerError, reason: reason))
        
        // Action
        try app.test(.GET, "global-crypto-market-data", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .internalServerError)
            XCTAssert(response.body.string.contains(reason))
        }
    }
    
    func testGetGlobalMarketData_success() async throws {
        // Setup
        let data = GlobalMarketData(
            cpiPercentage: 2.7,
            nextCPITimestamp: 1736947800,
            interestRatePercentage: 4.5,
            nextFOMCMeetingTimestamp: 1734548400
        )
        service.fetchGlobalMarketDataResult = .success(data)
        
        // Action
        try app.test(.GET, "global-market-data", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedData = try response.content.decode(GlobalMarketData.self)
            XCTAssertEqual(receivedData, data)
        }
    }
}
