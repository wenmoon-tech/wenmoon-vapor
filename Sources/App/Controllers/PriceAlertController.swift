import Fluent
import Vapor

struct PriceAlertController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let priceAlerts = routes.grouped("price_alerts")
        priceAlerts.get(use: index)
        priceAlerts.post(use: create)
        priceAlerts.group(":priceAlertID") { priceAlert in
            priceAlert.delete(use: delete)
        }
    }

    func index(req: Request) async throws -> [PriceAlert] {
        try await PriceAlert.query(on: req.db).all()
    }

    func create(req: Request) async throws -> PriceAlert {
        let priceAlert = try req.content.decode(PriceAlert.self)
        try await priceAlert.save(on: req.db)
        return priceAlert
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let priceAlert = try await PriceAlert.find(req.parameters.get("priceAlertID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await priceAlert.delete(on: req.db)
        return .noContent
    }
}
