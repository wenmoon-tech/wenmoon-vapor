import Vapor
import Fluent

struct CoinInfoProviderKey: StorageKey {
    typealias Value = CoinScannerService
}

func routes(_ app: Application) throws {
    // MARK: - Coins
    app.get("coins") { req -> EventLoopFuture<[Coin]> in
        let provider = getProvider(req)
        let currency = (try? req.query.get(Currency.self, at: "currency")) ?? .usd
        let page = (try? req.query.get(Int64.self, at: "page")) ?? 1
        let perPage = (try? req.query.get(Int64.self, at: "per_page")) ?? 250
        return provider.fetchCoins(onPage: page, perPage: perPage, currency: currency, req: req)
    }
    
    app.get("coin-details") { req -> EventLoopFuture<CoinDetails> in
        guard let id = try? req.query.get(String.self, at: "id"), !id.isEmpty else {
            return req.eventLoop.makeFailedFuture(
                Abort(.badRequest, reason: "Query parameter 'id' is required")
            )
        }
        let provider = getProvider(req)
        return provider.fetchCoinDetails(for: id, req: req)
    }
    
    app.get("chart-data") { req -> EventLoopFuture<[ChartData]> in
        do {
            let (id, timeframe, currency) = try validateChartDataQueryParams(req)
            let provider = getProvider(req)
            return provider.fetchChartData(for: id, on: timeframe, currency: currency, req: req)
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
    
    // MARK: - Search
    app.get("search") { req -> EventLoopFuture<[Coin]> in
        guard let query = try? req.query.get(String.self, at: "query"), !query.isEmpty else {
            return req.eventLoop.makeFailedFuture(
                Abort(.badRequest, reason: "Query parameter 'query' is required")
            )
        }
        let provider = getProvider(req)
        return provider.searchCoins(by: query, req: req)
    }
    
    // MARK: - Market Data
    app.get("market-data") { req -> EventLoopFuture<[String: MarketData]> in
        let provider = getProvider(req)
        guard let idsString = try? req.query.get(String.self, at: "ids"), !idsString.isEmpty else {
            return req.eventLoop.makeFailedFuture(
                Abort(.badRequest, reason: "Query parameter 'ids' is required")
            )
        }
        let ids = idsString.split(separator: ",").map { String($0) }
        let currency = (try? req.query.get(Currency.self, at: "currency")) ?? .usd
        return provider.fetchMarketData(for: ids, currency: currency, req: req)
    }
    
    // MARK: - Global Market Data
    app.get("fear-and-greed") { req -> EventLoopFuture<FearAndGreedIndex> in
        let provider = getProvider(req)
        return provider.fetchFearAndGreedIndex(req: req)
    }
    
    app.get("global-crypto-market-data") { req -> EventLoopFuture<GlobalCryptoMarketData> in
        let provider = getProvider(req)
        return provider.fetchGlobalCryptoMarketData(req: req)
    }
    
    app.get("global-market-data") { req -> EventLoopFuture<GlobalMarketData> in
        let provider = getProvider(req)
        return provider.fetchGlobalMarketData(req: req)
    }
    
    // MARK: - Price Alerts
    let headers = HTTPHeaders([("content-type", "application/json")])
    
    app.get("users", ":user_id", "price-alerts") { req -> EventLoopFuture<[PriceAlert]> in
        guard let userID = req.parameters.get("user_id") else {
            throw Abort(.badRequest, reason: "user_id parameter must not be empty")
        }
        
        guard let deviceToken = req.headers.first(name: "X-Device-ID") else {
            throw Abort(.badRequest, reason: "X-Device-ID header missing")
        }
        
        return PriceAlert.query(on: req.db)
            .filter(\.$userID == userID)
            .all()
            .flatMap { priceAlerts in
                let updateFutures = priceAlerts.map { priceAlert in
                    priceAlert.deviceToken = deviceToken
                    return priceAlert.update(on: req.db)
                }
                return updateFutures.flatten(on: req.eventLoop).transform(to: priceAlerts)
            }
    }
    
    app.post("users", ":user_id", "price-alert") { req -> EventLoopFuture<Response> in
        guard let userID = req.parameters.get("user_id") else {
            throw Abort(.badRequest, reason: "user_id parameter must not be empty")
        }
        
        do {
            let priceAlert = try req.content.decode(PriceAlert.self)
            
            guard let id = priceAlert.id, !id.isEmpty else {
                throw Abort(.badRequest, reason: "id parameter must not be empty")
            }
            
            guard priceAlert.targetPrice > 0 else {
                throw Abort(.badRequest, reason: "target_price must be greater than zero")
            }
            
            guard let deviceToken = req.headers.first(name: "X-Device-ID") else {
                throw Abort(.badRequest, reason: "X-Device-ID header missing")
            }
            
            priceAlert.userID = userID
            priceAlert.deviceToken = deviceToken
            
            return PriceAlert.query(on: req.db)
                .filter(\.$userID == userID)
                .filter(\.$symbol == priceAlert.symbol)
                .filter(\.$targetPrice == priceAlert.targetPrice)
                .first()
                .flatMap { existingPriceAlert in
                    if existingPriceAlert != nil {
                        return req.eventLoop.makeFailedFuture(
                            Abort(
                                .conflict,
                                reason: "Price alert already exists for this coin with the same target price"
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
    
    app.delete("users", ":user_id", "price-alert", ":id") { req -> EventLoopFuture<Response> in
        guard let userID = req.parameters.get("user_id") else {
            throw Abort(.badRequest, reason: "user_id parameter must not be empty")
        }
        
        guard let id = req.parameters.get("id") else {
            throw Abort(.badRequest, reason: "id parameter must not be empty")
        }
        
        return PriceAlert.query(on: req.db)
            .filter(\.$userID == userID)
            .filter(\.$id == id)
            .first()
            .flatMap { priceAlert -> EventLoopFuture<Response> in
                guard let priceAlert else {
                    return req.eventLoop.makeFailedFuture(
                        Abort(
                            .notFound,
                            headers: headers,
                            reason: "Could not find price alert with the following coin ID: \(id) for user ID: \(userID)"
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
    
    // MARK: - Helpers
    func validateChartDataQueryParams(_ req: Request) throws -> (String, Timeframe, Currency) {
        func getQueryParam<T: Decodable>(_ key: String) throws -> T {
            do {
                let value = try req.query.get(T.self, at: key)
                if let strValue = value as? String, strValue.isEmpty {
                    throw Abort(.badRequest, reason: "Query parameter '\(key)' is invalid or missing")
                }
                return value
            } catch {
                throw Abort(.badRequest, reason: "Query parameter '\(key)' is invalid or missing")
            }
        }
        
        let id: String = try getQueryParam("id")
        let timeframe: Timeframe = try getQueryParam("timeframe")
        let currency: Currency = try getQueryParam("currency")
        
        return (id, timeframe, currency)
    }
    
    func getProvider(_ req: Request) -> CoinScannerService {
        req.application.storage[CoinInfoProviderKey.self] ?? CoinScannerServiceImpl.shared
    }
}
