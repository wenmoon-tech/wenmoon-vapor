import Fluent
import APNS
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

    func checkPriceForAlerts(on req: Request) -> EventLoopFuture<Void> {
        PriceAlert.query(on: req.db).all().flatMap { priceAlerts in
            let priceAlertIDs = Set(priceAlerts.compactMap { $0.coinID }).joined(separator: ",")
            guard !priceAlertIDs.isEmpty else {
                return req.eventLoop.makeSucceededVoidFuture()
            }
            let url = "https://api.coingecko.com/api/v3/simple/price?ids=\(priceAlertIDs)&vs_currencies=usd"
            return req.client.get(URI(string: url)).flatMap { response in
                guard response.status == .ok else {
                    let errorMessage = "Failed to fetch coin prices: \(response.status)"
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: errorMessage))
                }

                guard let data = response.body else {
                    return req.eventLoop.makeFailedFuture(Abort(.badRequest))
                }

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                do {
                    let marketData = try decoder.decode([String: CoinMarketData].self, from: data)
                    return pushNotification(req, priceAlerts, marketData)
                } catch {
                    return req.eventLoop.makeFailedFuture(error)
                }
            }
        }
    }

    private func pushNotification(_ req: Request,
                                  _ priceAlerts: [PriceAlert],
                                  _ marketData: [String: CoinMarketData]) -> EventLoopFuture<Void> {
        var badgeCountByDeviceToken: [String: Int] = [:]
        var deleteAlertFutures: [EventLoopFuture<Void>] = []

        for priceAlert in priceAlerts {
            guard let currentPrice = marketData[priceAlert.coinID]?.currentPrice,
                  let deviceToken = priceAlert.deviceToken else {
                continue
            }
            if currentPrice >= priceAlert.targetPrice {
                let badgeCount = (badgeCountByDeviceToken[deviceToken] ?? .zero) + 1
                badgeCountByDeviceToken[deviceToken] = badgeCount
                let sendNotificationFuture = sendPushNotification(on: req,
                                                                  for: priceAlert,
                                                                  deviceToken: deviceToken,
                                                                  badge: badgeCount)
                deleteAlertFutures.append(sendNotificationFuture.flatMap {
                    priceAlert.delete(on: req.db)
                })
            }
        }
        return EventLoopFuture<Void>.andAllSucceed(deleteAlertFutures, on: req.eventLoop)
    }

    private func sendPushNotification(on req: Request,
                                      for priceAlert: PriceAlert,
                                      deviceToken: String,
                                      badge: Int) -> EventLoopFuture<Void> {
        let alert = APNSwiftAlert(title: "Price Alert",
                                  body: "Your price target of \(priceAlert.targetPrice) for \(priceAlert.coinName) is reached!")
        let aps = APNSwiftPayload(alert: alert, badge: badge, sound: .normal("cow.wav"))
        return req.apns.send(aps, to: deviceToken)
            .map { response in
                print("Push notification sent successfully: \(response)")
            }
            .flatMapError { error in
                print("Failed to send push notification: \(error.localizedDescription)")
                return req.eventLoop.makeFailedFuture(error)
            }
    }
}
