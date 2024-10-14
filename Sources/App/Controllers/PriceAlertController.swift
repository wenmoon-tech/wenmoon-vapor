import Fluent
import APNS
import Vapor

struct PriceAlertController {

    func checkPriceForAlerts(on req: Request) -> EventLoopFuture<Void> {
        PriceAlert.query(on: req.db).all().flatMap { priceAlerts in
            let priceAlertCoinIDs = Set(priceAlerts.compactMap { $0.coinID })
            guard !priceAlertCoinIDs.isEmpty else {
                return req.eventLoop.makeSucceededVoidFuture()
            }
            
            return Coin.query(on: req.db)
                .filter(\.$coinID ~~ priceAlertCoinIDs)
                .all()
                .flatMap { coins in
                    let coinMarketData = Dictionary(uniqueKeysWithValues: coins.map { ($0.coinID, $0) })
                    
                    let marketData = coinMarketData.mapValues { coin in
                        MarketData(currentPrice: coin.currentPrice,
                                   priceChange: coin.priceChangePercentage24H)
                    }
                    return pushNotification(req, priceAlerts, marketData)
                }
        }
    }

    private func pushNotification(_ req: Request,
                                  _ priceAlerts: [PriceAlert],
                                  _ marketData: [String: MarketData]) -> EventLoopFuture<Void> {
        var badgeCountByDeviceToken: [String: Int] = [:]
        var deleteAlertFutures: [EventLoopFuture<Void>] = []

        for priceAlert in priceAlerts {
            guard let currentPrice = marketData[priceAlert.coinID]?.currentPrice,
                  let deviceToken = priceAlert.deviceToken else {
                continue
            }

            let meetsCondition: Bool

            switch priceAlert.targetDirection {
            case .above:
                meetsCondition = currentPrice >= priceAlert.targetPrice
            case .below:
                meetsCondition = currentPrice <= priceAlert.targetPrice
            }

            if meetsCondition {
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
                                  body: "Your price target of \(priceAlert.targetPrice)$ for \(priceAlert.coinName) is reached!")
        let aps = APNSwiftPayload(alert: alert, badge: badge, sound: .normal("default"))
        let notification = PriceAlertNotification(coinID: priceAlert.coinID, aps: aps)
        return req.apns.send(notification, to: deviceToken)
            .map { response in
                print("Push notification sent successfully: \(response)")
            }
            .flatMapError { error in
                print("Failed to send push notification: \(error.localizedDescription)")
                return req.eventLoop.makeFailedFuture(error)
            }
    }
}
