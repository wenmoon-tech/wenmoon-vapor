@testable import App
import XCTVapor

func assertMarketDataEqual(_ received: [String: MarketData], _ expected: [String: MarketData]) {
    XCTAssertEqual(received.count, expected.count)
    for (id, receivedData) in received {
        let expectedData = expected[id]!
        XCTAssertEqual(receivedData, expectedData)
    }
}
