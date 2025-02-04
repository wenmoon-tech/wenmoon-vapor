@testable import App
import Fluent
import XCTVapor

final class PriceAlertTests: XCTestCase {
    // MARK: - Properties
    var app: Application!
    var headers: HTTPHeaders!
    var userID: String!
    
    // MARK: - Setup
    override func setUp() async throws {
        app = try await Application.testable()
        headers = setHeaders()
        userID = "example.email@gmail.com"
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }
    
    // MARK: - Tests
    // Get Price Alerts
    func testGetPriceAlerts_success() async throws {
        // Setup
        let priceAlerts = try await createPriceAlerts()
        
        // Action
        try app.test(.GET, "users/\(userID!)/price-alerts", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedPriceAlerts = try response.content.decode([PriceAlert].self)
            assertPriceAlertsEqual(receivedPriceAlerts, priceAlerts)
        }
    }
    
    func testGetPriceAlerts_emptyResult() throws {
        // Action
        try app.test(.GET, "users/\(userID!)/price-alerts", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedPriceAlerts = try response.content.decode([PriceAlert].self)
            XCTAssert(receivedPriceAlerts.isEmpty)
        }
    }
    
    func testGetPriceAlerts_invalidUserID() async throws {
        // Setup
        let priceAlerts = try await createPriceAlerts()
        userID = "invalid-user-id"
        
        // Action
        headers = setHeaders(deviceToken: "non-existing-device-token")
        try app.test(.GET, "users/\(userID!)/price-alerts", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedPriceAlerts = try response.content.decode([PriceAlert].self)
            XCTAssert(receivedPriceAlerts.isEmpty)
        }
    }
    
    // Post Price Alert
    func testPostPriceAlert_success() async throws {
        // Setup
        let priceAlert = makePriceAlert()
        
        // Action
        let postedPriceAlert = try postPriceAlert(priceAlert)
        try app.test(.GET, "users/\(userID!)/price-alerts", headers: headers) { response in
            // Assertions
            let receivedPriceAlerts = try response.content.decode([PriceAlert].self)
            assertPriceAlertsEqual(receivedPriceAlerts, [postedPriceAlert])
        }
    }
    
    func testPostPriceAlert_duplication() async throws {
        // Setup
        let priceAlert = makePriceAlert()
        
        // Action
        _ = try postPriceAlert(priceAlert)
        try app.test(.POST, "users/\(userID!)/price-alert", headers: headers, beforeRequest: { req in
            try req.content.encode(priceAlert)
        }, afterResponse: { response in
            // Assertions
            XCTAssertEqual(response.status, .conflict)
            XCTAssertTrue(response.body.string.contains("Price alert already exists for this coin with the same target price"))
        })
    }
    
    func testPostPriceAlert_emptyID() throws {
        // Setup
        let emptyPriceAlert = makePriceAlert(id: "")
        
        // Action
        try app.test(.POST, "users/\(userID!)/price-alert", headers: headers, beforeRequest: { req in
            try req.content.encode(emptyPriceAlert)
        }, afterResponse: { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssertTrue(response.body.string.contains("id parameter must not be empty"))
        })
    }
    
    func testPostPriceAlert_invalidTargetPrice() async throws {
        // Setup
        let invalidPriceAlert = makePriceAlert(targetPrice: -1)
        
        // Action
        try app.test(.POST, "users/\(userID!)/price-alert", headers: headers, beforeRequest: { req in
            try req.content.encode(invalidPriceAlert)
        }, afterResponse: { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssertTrue(response.body.string.contains("target_price must be greater than zero"))
        })
    }
    
    // Delete Price Alert
    func testDeletePriceAlert_success() async throws {
        // Setup
        let priceAlert = try await createPriceAlert()
        
        // Action: Delete the price alert with a valid ID and headers
        try app.test(.DELETE, "users/\(userID!)/price-alert/\(priceAlert.id!)", headers: headers) { response in
            // Assertions: Confirm deletion and check the response
            XCTAssertEqual(response.status, .ok)
            let deletedPriceAlert = try response.content.decode(PriceAlert.self)
            assertPriceAlertsEqual([deletedPriceAlert], [priceAlert])
            
            // Action: Verify deletion by fetching all alerts
            try app.test(.GET, "users/\(userID!)/price-alerts", headers: headers) { secondResponse in
                // Assertions: Check that no alerts remain
                XCTAssertEqual(secondResponse.status, .ok)
                let priceAlerts = try secondResponse.content.decode([PriceAlert].self)
                XCTAssert(priceAlerts.isEmpty)
            }
        }
    }
    
    func testDeletePriceAlert_invalidID() async throws {
        // Setup
        let invalidID = "invalid-id"
        
        // Action
        try app.test(.DELETE, "users/\(userID!)/price-alert/\(invalidID)", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .notFound)
            XCTAssertTrue(response.body.string.contains("Could not find price alert with the following coin ID: \(invalidID) for user ID: \(userID!)"))
        }
    }
    
    func testDeletePriceAlert_invalidUserID() async throws {
        // Setup
        let priceAlert = try await createPriceAlert()
        userID = "invalid-user-id"
        
        // Action
        try app.test(.DELETE, "users/\(userID!)/price-alert/\(priceAlert.id!)", headers: headers) { response in
            // Assertions
            XCTAssertEqual(response.status, .notFound)
            XCTAssertTrue(response.body.string.contains("Could not find price alert with the following coin ID: \(priceAlert.id!) for user ID: \(userID!)"))
        }
    }
    
    // MARK: - Helper Methods
    // Make/Create Price Alert
    private func makePriceAlert(
        id: String = "price-alert-1",
        symbol: String = "C-1",
        targetPrice: Double = .random(in: 0.01...100000),
        targetDirection: PriceAlert.TargetDirection = Bool.random() ? .below : .above,
        userID: String = "example.email@gmail.com",
        deviceToken: String = "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870030"
    ) -> PriceAlert {
        .init(
            id: id,
            symbol: symbol,
            targetPrice: targetPrice,
            targetDirection: targetDirection,
            userID: userID,
            deviceToken: deviceToken
        )
    }
    
    private func makePriceAlerts(count: Int = 10) -> [PriceAlert] {
        (1...count).map { index in
            makePriceAlert(
                id: "price-alert-\(index)",
                symbol: "C-\(index)"
            )
        }
    }
    
    private func createPriceAlert(_ priceAlert: PriceAlert? = nil) async throws -> PriceAlert {
        let priceAlert = priceAlert ?? makePriceAlert()
        try await priceAlert.save(on: app.db)
        return priceAlert
    }
    
    private func createPriceAlerts(count: Int = 10) async throws -> [PriceAlert] {
        try await makePriceAlerts(count: count).asyncMap { priceAlert in
            try await createPriceAlert(priceAlert)
        }
    }
    
    private func assertPriceAlertsEqual(_ priceAlerts: [PriceAlert], _ expectedPriceAlerts: [PriceAlert]) {
        XCTAssertEqual(priceAlerts.count, expectedPriceAlerts.count)
        for (index, _) in priceAlerts.enumerated() {
            let priceAlert = priceAlerts[index]
            let expectedPriceAlert = expectedPriceAlerts[index]
            XCTAssertEqual(priceAlert.id, expectedPriceAlert.id)
            XCTAssertEqual(priceAlert.symbol, expectedPriceAlert.symbol)
            XCTAssertEqual(priceAlert.targetPrice, expectedPriceAlert.targetPrice)
            XCTAssertEqual(priceAlert.targetDirection, expectedPriceAlert.targetDirection)
            XCTAssertEqual(priceAlert.userID, expectedPriceAlert.userID)
            XCTAssertEqual(priceAlert.deviceToken, expectedPriceAlert.deviceToken)
        }
    }
    
    private func postPriceAlert(_ priceAlert: PriceAlert, expectedStatus: HTTPResponseStatus = .ok) throws -> PriceAlert {
        var receivedPriceAlert: PriceAlert!
        try app.test(.POST, "users/\(userID!)/price-alert", headers: headers, beforeRequest: { req in
            try req.content.encode(priceAlert)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, expectedStatus)
            receivedPriceAlert = try response.content.decode(PriceAlert.self)
        })
        return receivedPriceAlert
    }
    
    private func setHeaders(
        deviceToken: String? = "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870030",
        apiKey: String = "9178693a7845b10ce1cedfe571f0682b9051aa793c41545739ce724f3ae272db"
    ) -> HTTPHeaders {
        guard let deviceToken else {
            return HTTPHeaders([("X-API-Key", apiKey)])
        }
        return HTTPHeaders([("X-Device-ID", deviceToken), ("X-API-Key", apiKey)])
    }
}
