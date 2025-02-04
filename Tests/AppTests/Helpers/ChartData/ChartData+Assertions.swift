@testable import App
import XCTVapor

func assertChartDataEqual(_ received: [ChartData], _ expected: [ChartData]) {
    XCTAssertEqual(received.count, expected.count)
    for (index, receivedData) in received.enumerated() {
        let expectedData = expected[index]
        XCTAssertEqual(receivedData, expectedData)
    }
}
