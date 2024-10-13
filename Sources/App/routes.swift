import Fluent
import Vapor

func routes(_ app: Application) throws {
    
    // MARK: - Coins
    
    app.get("coins") { req -> EventLoopFuture<[Coin]> in
        let page = (try? req.query.get(Int.self, at: "page")) ?? 1
        let perPage = (try? req.query.get(Int.self, at: "per_page")) ?? 250
        
        let lowerBound = (page - 1) * perPage
        let upperBound = lowerBound + perPage
        
        return Coin.query(on: req.db)
            .sort(\.$marketCapRank, .ascending)
            .range(lowerBound..<upperBound)
            .all()
    }
    
    // MARK: - Price Alerts
    
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
                    
                    let body: Data
                    do {
                        let encoder = JSONEncoder()
                        body = try encoder.encode(priceAlert)
                    } catch {
                        return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
                    }
                    
                    guard count == .zero else {
                        let response = Response(status: .ok, headers: headers, body: .init(data: body))
                        return req.eventLoop.makeSucceededFuture(response)
                    }
                    return priceAlert.save(on: req.db).flatMapThrowing {
                        Response(status: .ok, headers: headers, body: .init(data: body))
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
            .flatMap { priceAlert -> EventLoopFuture<Response> in
                let headers = HTTPHeaders([("content-type", "application/json")])
                guard let priceAlert else {
                    return req.eventLoop.makeFailedFuture(Abort(.notFound,
                                                                headers: headers,
                                                                reason: "Could not find price alert with the following coin id: \(coinID)"))
                }
                
                let body: Data
                do {
                    let encoder = JSONEncoder()
                    body = try encoder.encode(priceAlert)
                } catch {
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError))
                }
                
                return priceAlert.delete(on: req.db).flatMapThrowing {
                    Response(status: .ok, headers: headers, body: .init(data: body))
                }
            }
    }
}
