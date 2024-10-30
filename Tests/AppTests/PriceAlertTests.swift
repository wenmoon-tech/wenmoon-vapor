@testable import App
import Fluent
import XCTVapor

final class PriceAlertTests: XCTestCase {
    // MARK: - Properties
    var app: Application!
    var headers: HTTPHeaders!
    
    // MARK: - Setup
    override func setUp() async throws {
        app = try await Application.testable()
        headers = HTTPHeaders([("X-Device-ID", "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870030")])
    }
    
    override func tearDown() async throws {
        try await app.autoRevert()
        try await app.asyncShutdown()
    }
    
    // MARK: - Tests
    // Get Price Alerts
    func testGetPriceAlertsSuccess() async throws {
        // Setup
        let priceAlerts = try await createPriceAlerts()
        // Action
        try app.test(.GET, "price-alerts") { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedPriceAlerts = try response.content.decode([PriceAlert].self)
            assertPriceAlertsEqual(receivedPriceAlerts, priceAlerts)
        }
    }
    
    func testGetPriceAlertsEmptyArray() throws {
        // Action
        try app.test(.GET, "price-alerts") { response in
            // Assertions
            XCTAssertEqual(response.status, .ok)
            let receivedPriceAlerts = try response.content.decode([PriceAlert].self)
            XCTAssert(receivedPriceAlerts.isEmpty)
        }
    }
    
    func testGetSpecificPriceAlerts() async throws {
        // Setup
        let priceAlert = try await createPriceAlert()
        // Action: Fetch alerts with the correct device token
        try app.test(.GET, "price-alerts", headers: headers) { response in
            // Assertions: Check that the fetched alert matches the created one
            XCTAssertEqual(response.status, .ok)
            let receivedPriceAlerts = try response.content.decode([PriceAlert].self)
            assertPriceAlertsEqual(receivedPriceAlerts, [priceAlert])
        }
        
        // Action: Fetch alerts with a non-existing device token
        headers = HTTPHeaders([("X-Device-ID", "non-existing-device-token")])
        try app.test(.GET, "price-alerts", headers: headers) { response in
            // Assertions: Check that no alerts are returned
            XCTAssertEqual(response.status, .ok)
            let receivedPriceAlerts = try response.content.decode([PriceAlert].self)
            XCTAssert(receivedPriceAlerts.isEmpty)
        }
    }
    
    // Post Price Alert
    func testPostPriceAlertSuccess() async throws {
        // Setup
        let priceAlert = makePriceAlert()
        // Action
        let postedPriceAlert = try postPriceAlert(priceAlert)
        try app.test(.GET, "price-alerts", afterResponse: { response in
            // Assertions
            let receivedPriceAlerts = try response.content.decode([PriceAlert].self)
            assertPriceAlertsEqual(receivedPriceAlerts, [postedPriceAlert])
        })
    }
    
    func testPostDuplicatePriceAlert() async throws {
        // Setup
        let priceAlert = makePriceAlert()
        // Action
        _ = try postPriceAlert(priceAlert)
        try app.test(.POST, "price-alert", headers: headers, beforeRequest: { req in
            try req.content.encode(priceAlert)
        }, afterResponse: { response in
            // Assertions
            XCTAssertEqual(response.status, .conflict)
            XCTAssertTrue(response.body.string.contains("Price alert already exists for this coin and device."))
        })
    }
    
    func testPostEmptyPriceAlert() throws {
        // Setup
        let emptyPriceAlert = makePriceAlert(id: "")
        // Action
        try app.test(.POST, "price-alert", beforeRequest: { req in
            try req.content.encode(emptyPriceAlert)
        }, afterResponse: { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssertTrue(response.body.string.contains("id parameter must not be empty"))
        })
    }
    
    func testPostInvalidPriceAlert() async throws {
        // Setup
        let invalidPriceAlert = makePriceAlert(targetPrice: -1)
        // Action
        try app.test(.POST, "price-alert", beforeRequest: { req in
            try req.content.encode(invalidPriceAlert)
        }, afterResponse: { response in
            // Assertions
            XCTAssertEqual(response.status, .badRequest)
            XCTAssertTrue(response.body.string.contains("target_price must be greater than zero"))
        })
    }
    
    // Delete Price Alert
    func testDeletePriceAlert() async throws {
        // Setup
        let priceAlert = try await createPriceAlert()
        // Action: Delete the price alert with a valid ID and headers
        try app.test(.DELETE, "price-alert/\(priceAlert.id!)", headers: headers) { response in
            // Assertions: Confirm deletion and check the response
            XCTAssertEqual(response.status, .ok)
            let deletedPriceAlert = try response.content.decode(PriceAlert.self)
            assertPriceAlertsEqual([deletedPriceAlert], [priceAlert])
            
            // Action: Verify deletion by fetching all alerts
            try app.test(.GET, "price-alerts") { secondResponse in
                // Assertions: Check that no alerts remain
                XCTAssertEqual(secondResponse.status, .ok)
                let priceAlerts = try secondResponse.content.decode([PriceAlert].self)
                XCTAssertEqual(priceAlerts.count, .zero)
            }
        }
        
        // Action: Attempt to delete a non-existing alert
        let invalidCoinID = "invalid-coin-id"
        try app.test(.DELETE, "price-alert/\(invalidCoinID)", headers: headers) { response in
            // Assertions: Check for not found status and error message
            XCTAssertEqual(response.status, .notFound)
            XCTAssertTrue(response.body.string.contains("Could not find price alert with the following coin id: \(invalidCoinID)"))
        }
        
        // Action: Attempt deletion without providing the required header
        try app.test(.DELETE, "price-alert/\(priceAlert.id!)") { response in
            // Assertions: Check for bad request status due to missing header
            XCTAssertEqual(response.status, .badRequest)
            XCTAssertTrue(response.body.string.contains("X-Device-ID header missing"))
        }
    }
    
    // MARK: - Helper Methods
    // Make/Create Price Alert
    private func makePriceAlert(
        id: String = "price-alert-1",
        name: String = "Price Alert 1",
        targetPrice: Double = .random(in: 0.01...100000),
        targetDirection: PriceAlert.TargetDirection = Bool.random() ? .below : .above,
        deviceToken: String = "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870030"
    ) -> PriceAlert {
        .init(
            id: id,
            name: name,
            targetPrice: targetPrice,
            targetDirection: targetDirection,
            deviceToken: deviceToken
        )
    }
    
    private func makePriceAlerts(count: Int = 10) -> [PriceAlert] {
        (1...count).map { index in
            makePriceAlert(
                id: "price-alert-\(index)",
                name: "Price Alert \(index)"
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
    
    // Assertions
    private func assertPriceAlertsEqual(_ priceAlerts: [PriceAlert], _ expectedPriceAlerts: [PriceAlert]) {
        XCTAssertEqual(priceAlerts.count, expectedPriceAlerts.count)
        for (index, _) in priceAlerts.enumerated() {
            let priceAlert = priceAlerts[index]
            let expectedPriceAlert = expectedPriceAlerts[index]
            XCTAssertEqual(priceAlert.id, expectedPriceAlert.id)
            XCTAssertEqual(priceAlert.name, expectedPriceAlert.name)
            XCTAssertEqual(priceAlert.targetPrice, expectedPriceAlert.targetPrice)
            XCTAssertEqual(priceAlert.targetDirection, expectedPriceAlert.targetDirection)
            XCTAssertEqual(priceAlert.deviceToken, expectedPriceAlert.deviceToken)
        }
    }
    
    // Post Price Alert
    private func postPriceAlert(_ priceAlert: PriceAlert, expectedStatus: HTTPResponseStatus = .ok) throws -> PriceAlert {
        var receivedPriceAlert: PriceAlert!
        try app.test(.POST, "price-alert", headers: headers, beforeRequest: { req in
            try req.content.encode(priceAlert)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, expectedStatus)
            receivedPriceAlert = try response.content.decode(PriceAlert.self)
        })
        return receivedPriceAlert
    }
}
