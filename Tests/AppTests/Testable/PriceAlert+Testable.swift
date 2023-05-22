@testable import App
import Fluent

extension PriceAlert {
    static func create(coinID: String = "bitcoin",
                       coinName: String = "Bitcoin",
                       targetPrice: Double = 30000.0,
                       targetDirection: TargetDirection = .above,
                       deviceToken: String = "98a6de3ab414ef58b9aa38e8cf1570a4d329e3235ec8c0f343fe75ae51870030") -> PriceAlert {
        PriceAlert(coinID: coinID,
                   coinName: coinName,
                   targetPrice: targetPrice,
                   targetDirection: targetDirection,
                   deviceToken: deviceToken)
    }

    static func create(priceAlert: PriceAlert = .create(), on database: Database) async throws -> PriceAlert {
        try await priceAlert.save(on: database).get()
        return priceAlert
    }
}
