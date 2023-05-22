import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get("price-alerts") { req -> EventLoopFuture<[PriceAlert]> in
        guard let deviceToken = req.headers.first(name: "X-Device-ID") else {
            return PriceAlert.query(on: req.db).all()
        }
        return PriceAlert.query(on: req.db)
            .filter(\.$deviceToken == deviceToken)
            .all()
    }

    app.post("price-alert") { req -> EventLoopFuture<Response> in
        do {
            let priceAlert = try req.content.decode(PriceAlert.self)
            guard !priceAlert.coinID.isEmpty else {
                throw Abort(.badRequest, reason: "coin_id parameter must not be empty")
            }

            guard let deviceToken = req.headers.first(name: "X-Device-ID") else {
                throw Abort(.badRequest, reason: "X-Device-ID header missing")
            }

            priceAlert.deviceToken = deviceToken
            return PriceAlert.query(on: req.db)
                .filter(\.$deviceToken == deviceToken)
                .filter(\.$coinID == priceAlert.coinID)
                .count()
                .flatMap { count in
                    let headers = HTTPHeaders([("content-type", "application/json")])
                    guard count == .zero else {
                        let body = ByteBuffer(string: "Price alert with id \(priceAlert.coinID) already exists for this device")
                        let response = Response(status: .ok, headers: headers, body: .init(buffer: body))
                        return req.eventLoop.makeSucceededFuture(response)
                    }
                    return priceAlert.save(on: req.db)
                        .flatMapThrowing {
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = .prettyPrinted
                            let body = ByteBuffer(data: try encoder.encode(priceAlert))
                            let response = Response(status: .ok, headers: headers, body: .init(buffer: body))
                            return response
                        }
                }
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }

    app.delete("price-alert", ":coin_id") { req -> EventLoopFuture<Response> in
        guard let coinID = req.parameters.get("coin_id") else {
            throw Abort(.badRequest)
        }

        guard let deviceToken = req.headers.first(name: "X-Device-ID") else {
            throw Abort(.badRequest, reason: "X-Device-ID header missing")
        }

        return PriceAlert.query(on: req.db)
            .filter(\.$deviceToken == deviceToken)
            .filter(\.$coinID == coinID)
            .first()
            .flatMap { priceAlert in
                let headers = HTTPHeaders([("content-type", "application/json")])
                guard let priceAlert else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound,
                                                                headers: headers,
                                                                reason: "Could not find price alert with following coin id: \(coinID)"))
                }
                return priceAlert.delete(on: req.db)
                    .transform(to: Response(status: .ok,
                                            headers: headers,
                                            body: .init(buffer: ByteBuffer(string: "Price alert for coin \(coinID) has been deleted."))))
            }
    }

    try app.register(collection: PriceAlertController())
}
