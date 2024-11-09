import Fluent
import Vapor

func routes(_ app: Application) throws {
    // MARK: - Coins
    app.get("coins") { req -> EventLoopFuture<[Coin]> in
        // Check if `ids` query parameter is provided
        if let idsString = try? req.query.get(String.self, at: "ids") {
            let ids = idsString.split(separator: ",").map { String($0) }
            return Coin.query(on: req.db)
                .filter(\.$id ~~ ids)
                .sort(\.$marketCapRank, .ascending)
                .all()
        }
        
        // Default to pagination if `ids` is not provided
        let page = (try? req.query.get(Int.self, at: "page")) ?? 1
        let perPage = (try? req.query.get(Int.self, at: "per_page")) ?? 250
        
        guard page > 0, perPage > 0 else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Page and per_page must be positive integers."))
        }
        
        let lowerBound = (page - 1) * perPage
        let upperBound = lowerBound + perPage
        
        return Coin.query(on: req.db)
            .sort(\.$marketCapRank, .ascending)
            .range(lowerBound..<upperBound)
            .all()
    }
    
    app.get("search") { req -> EventLoopFuture<[Coin]> in
        guard let searchTerm = try? req.query.get(String.self, at: "query"), !searchTerm.isEmpty else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Query parameter 'query' is required"))
        }
        
        return Coin.query(on: req.db)
            .group(.or) { group in
                group
                    .filter(\.$name ~~ searchTerm)
                    .filter(\.$id ~~ searchTerm)
            }
            .sort(\.$marketCapRank, .ascending)
            .all()
    }
    
    app.get("market-data") { req -> EventLoopFuture<[String: MarketData]> in
        guard let idsString = try? req.query.get(String.self, at: "ids"), !idsString.isEmpty else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Query parameter 'ids' is required"))
        }
        
        let ids = idsString.split(separator: ",").map { String($0) }
        
        return Coin.query(on: req.db)
            .filter(\.$id ~~ ids)
            .all()
            .map { coins in
                var marketDataDict: [String: MarketData] = [:]
                for coin in coins {
                    let marketData = MarketData(
                        currentPrice: coin.currentPrice,
                        marketCap: coin.marketCap,
                        marketCapRank: coin.marketCapRank,
                        fullyDilutedValuation: coin.fullyDilutedValuation,
                        totalVolume: coin.totalVolume,
                        high24H: coin.high24H,
                        low24H: coin.low24H,
                        priceChange24H: coin.priceChange24H,
                        priceChangePercentage24H: coin.priceChangePercentage24H,
                        marketCapChange24H: coin.marketCapChange24H,
                        marketCapChangePercentage24H: coin.marketCapChangePercentage24H,
                        circulatingSupply: coin.circulatingSupply,
                        totalSupply: coin.totalSupply,
                        ath: coin.ath,
                        athChangePercentage: coin.athChangePercentage,
                        athDate: coin.athDate,
                        atl: coin.atl,
                        atlChangePercentage: coin.atlChangePercentage,
                        atlDate: coin.atlDate
                    )
                    marketDataDict[coin.id!] = marketData
                }
                return marketDataDict
            }
    }
    
    // MARK: - Price Alerts
    let headers = HTTPHeaders([("content-type", "application/json")])
    
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
            
            guard !priceAlert.id!.isEmpty else {
                throw Abort(.badRequest, reason: "id parameter must not be empty")
            }
            
            guard priceAlert.targetPrice > 0 else {
                throw Abort(.badRequest, reason: "target_price must be greater than zero")
            }
            
            guard let deviceToken = req.headers.first(name: "X-Device-ID") else {
                throw Abort(.badRequest, reason: "X-Device-ID header missing")
            }
            
            priceAlert.deviceToken = deviceToken
            
            return PriceAlert.query(on: req.db)
                .filter(\.$deviceToken == deviceToken)
                .filter(\.$id == priceAlert.id!)
                .first()
                .flatMap { existingPriceAlert in
                    if existingPriceAlert != nil {
                        return req.eventLoop.makeFailedFuture(
                            Abort(
                                .conflict,
                                reason: "Price alert already exists for this coin and device."
                            )
                        )
                    } else {
                        return priceAlert.save(on: req.db).flatMapThrowing {
                            Response(
                                status: .ok,
                                headers: headers,
                                body: .init(data: try JSONEncoder().encode(priceAlert))
                            )
                        }
                    }
                }
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
    
    app.delete("price-alert", ":id") { req -> EventLoopFuture<Response> in
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        
        guard let deviceToken = req.headers.first(name: "X-Device-ID") else {
            throw Abort(.badRequest, reason: "X-Device-ID header missing")
        }
        
        return PriceAlert.query(on: req.db)
            .filter(\.$deviceToken == deviceToken)
            .filter(\.$id == id)
            .first()
            .flatMap { priceAlert -> EventLoopFuture<Response> in
                guard let priceAlert else {
                    return req.eventLoop.makeFailedFuture(
                        Abort(
                            .notFound,
                            headers: headers,
                            reason: "Could not find price alert with the following coin id: \(id)"
                        )
                    )
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
