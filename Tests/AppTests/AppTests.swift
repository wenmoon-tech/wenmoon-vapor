@testable import App
import XCTVapor

final class AppTests: XCTestCase {

    // MARK: - Properties

    var app: Application!

    // MARK: - Setup

    override func setUp() async throws {
        app = try await Application.testable()
    }

    override func tearDown() {
        app.shutdown()
    }

    // MARK: - Tests

    func testGetAllPriceAlertsSuccess() async throws {
        let priceAlert = try await PriceAlert.create(on: app.db)

        try app.test(.GET, "price-alerts") { response in
            XCTAssertEqual(response.status, .ok)

            let priceAlerts = try response.content.decode([PriceAlert].self)
            XCTAssertEqual(priceAlerts.count, 1)
            XCTAssertEqual(priceAlerts.first?.coinID, priceAlert.coinID)
            XCTAssertEqual(priceAlerts.first?.coinName, priceAlert.coinName)
            XCTAssertEqual(priceAlerts.first?.targetPrice, priceAlert.targetPrice)
            XCTAssertEqual(priceAlerts.first?.targetDirection, priceAlert.targetDirection)
            XCTAssertEqual(priceAlerts.first?.deviceToken, priceAlert.deviceToken)
        }
    }

    func testGetAllPriceAlertsEmptyArray() throws {
        try app.test(.GET, "price-alerts") { response in
            XCTAssertEqual(response.status, .ok)

            let priceAlerts = try response.content.decode([PriceAlert].self)
            XCTAssertTrue(priceAlerts.isEmpty)
        }
    }

    func testGetSpecificPriceAlertsSuccess() async throws {
        let mockPriceAlert = PriceAlert.create(deviceToken: "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870031")
        let priceAlert = try await PriceAlert.create(priceAlert: mockPriceAlert, on: app.db)
        let headers = HTTPHeaders([("content-type", "application/json"),
                                   ("X-Device-ID", "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870031")])

        try app.test(.GET, "price-alerts", headers: headers) { response in
            XCTAssertEqual(response.status, .ok)

            let priceAlerts = try response.content.decode([PriceAlert].self)
            XCTAssertEqual(priceAlerts.count, 1)
            XCTAssertEqual(priceAlerts.first?.coinID, priceAlert.coinID)
            XCTAssertEqual(priceAlerts.first?.coinName, priceAlert.coinName)
            XCTAssertEqual(priceAlerts.first?.targetPrice, priceAlert.targetPrice)
            XCTAssertEqual(priceAlerts.first?.targetDirection, priceAlert.targetDirection)
            XCTAssertEqual(priceAlerts.first?.deviceToken, priceAlert.deviceToken)
        }
    }

    func testGetSpecificPriceAlertsEmptyArray() async throws {
        let mockPriceAlert = PriceAlert.create(deviceToken: "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870031")
        _ = try await PriceAlert.create(priceAlert: mockPriceAlert, on: app.db)
        let headers = HTTPHeaders([("content-type", "application/json"),
                                   ("X-Device-ID", "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870030")])

        try app.test(.GET, "price-alerts", headers: headers) { response in
            XCTAssertEqual(response.status, .ok)

            let priceAlerts = try response.content.decode([PriceAlert].self)
            XCTAssertTrue(priceAlerts.isEmpty)
        }
    }

    func testPostPriceAlertSuccess() throws {
        let priceAlert = PriceAlert.create()
        let receivedPriceAlert = try postPriceAlert(priceAlert)

        try app.test(.GET, "price-alerts", afterResponse: { response in
            let priceAlerts = try response.content.decode([PriceAlert].self)

            XCTAssertEqual(priceAlerts.count, 1)
            XCTAssertEqual(priceAlerts.first?.coinID, receivedPriceAlert?.coinID)
            XCTAssertEqual(priceAlerts.first?.coinName, receivedPriceAlert?.coinName)
            XCTAssertEqual(priceAlerts.first?.targetPrice, receivedPriceAlert?.targetPrice)
            XCTAssertEqual(priceAlerts.first?.targetDirection, priceAlert.targetDirection)
            XCTAssertEqual(priceAlerts.first?.deviceToken, receivedPriceAlert?.deviceToken)
        })

        let expectedBodyMessage = "Price alert with id \(priceAlert.coinID) already exists"
        let secondReceivedPriceAlert = try postPriceAlert(priceAlert, expectedBodyMessage: expectedBodyMessage)
        XCTAssertNil(secondReceivedPriceAlert)
    }

    func testPostPriceAlertFailure() throws {
        let priceAlert = PriceAlert.create(coinID: "")

        try app.test(.POST, "price-alert", beforeRequest: { req in
            try req.content.encode(priceAlert)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, .badRequest)

            let expectedBodyMessage = "coin_id parameter must not be empty"
            XCTAssertTrue(response.body.string.contains(expectedBodyMessage))
        })
    }

    func testDeletePriceAlertSuccess() async throws {
        let priceAlert = try await PriceAlert.create(on: app.db)
        let headers = HTTPHeaders([("content-type", "application/json"),
                                   ("X-Device-ID", "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870030")])

        try app.test(.DELETE, "price-alert/\(priceAlert.coinID)", headers: headers) { response in
            XCTAssertEqual(response.status, .ok)
            XCTAssertEqual(response.body.string, "Price alert for coin \(priceAlert.coinID) has been deleted.")

            try app.test(.GET, "price-alerts") { secondResponse in
                XCTAssertEqual(secondResponse.status, .ok)

                let priceAlerts = try secondResponse.content.decode([PriceAlert].self)
                XCTAssertEqual(priceAlerts.count, .zero)
            }
        }
    }

    func testDeletePriceAlertInvalidCoinID() throws {
        let invalidCoinID = "invalid-coin-id"
        let expectedBodyMessage = "Could not find price alert with following coin id: \(invalidCoinID)"
        let headers = HTTPHeaders([("content-type", "application/json"),
                                   ("X-Device-ID", "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870030")])

        try app.test(.DELETE, "price-alert/\(invalidCoinID)", headers: headers) { response in
            XCTAssertEqual(response.status, .notFound)
            XCTAssert(response.body.string.contains(expectedBodyMessage))
        }
    }

    func testDeletePriceAlertMissingHeader() async throws {
        let priceAlert = try await PriceAlert.create(on: app.db)
        let expectedBodyMessage = "X-Device-ID header missing"

        try app.test(.DELETE, "price-alert/\(priceAlert.coinID)") { response in
            XCTAssertEqual(response.status, .badRequest)
            XCTAssert(response.body.string.contains(expectedBodyMessage))
        }
    }

    // MARK: - Helpers

    private func postPriceAlert(_ priceAlert: PriceAlert,
                                expectedStatus: HTTPResponseStatus = .ok,
                                expectedBodyMessage: String? = nil) throws -> PriceAlert? {
        var receivedPriceAlert: PriceAlert?
        let headers = HTTPHeaders([("content-type", "application/json"),
                                   ("X-Device-ID", "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870030")])

        try app.test(.POST, "price-alert", headers: headers, beforeRequest: { req in
            try req.content.encode(priceAlert)
        }, afterResponse: { response in
            XCTAssertEqual(response.status, expectedStatus)

            if let expectedBodyMessage {
                XCTAssert(response.body.string.contains(expectedBodyMessage))
                receivedPriceAlert = nil
            } else {
                receivedPriceAlert = try response.content.decode(PriceAlert.self)
                XCTAssertEqual(receivedPriceAlert?.coinID, priceAlert.coinID)
                XCTAssertEqual(receivedPriceAlert?.coinName, priceAlert.coinName)
                XCTAssertEqual(receivedPriceAlert?.targetPrice, priceAlert.targetPrice)
                XCTAssertEqual(receivedPriceAlert?.targetDirection, priceAlert.targetDirection)
                XCTAssertEqual(receivedPriceAlert?.deviceToken, priceAlert.deviceToken)
            }
        })
        return receivedPriceAlert
    }
}
