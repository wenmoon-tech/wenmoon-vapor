import Fluent
import APNS
import Vapor

struct PriceAlertController {
    func checkPriceForAlerts(on req: Request) -> EventLoopFuture<Void> {
        PriceAlert.query(on: req.db)
            .all()
            .flatMap { priceAlerts in
                let priceAlertCoinIDs = Set(priceAlerts.compactMap { $0.id })
                guard !priceAlertCoinIDs.isEmpty else {
                    return req.eventLoop.makeSucceededVoidFuture()
                }
                
                return Coin.query(on: req.db)
                    .filter(\.$id ~~ priceAlertCoinIDs)
                    .all()
                    .flatMap { coins in
                        let marketData = self.extractMarketData(from: coins)
                        return self.pushNotification(req, priceAlerts, marketData)
                    }
            }
            .flatMapError { error in
                print("Error fetching price alerts: \(error.localizedDescription)")
                return req.eventLoop.makeFailedFuture(error)
            }
    }
    
    private func extractMarketData(from coins: [Coin]) -> [String: MarketData] {
        Dictionary(uniqueKeysWithValues: coins.compactMap { coin in
            (coin.id!, MarketData(currentPrice: coin.currentPrice, priceChange: coin.priceChange))
        })
    }
    
    private func pushNotification(
        _ req: Request,
        _ priceAlerts: [PriceAlert],
        _ marketData: [String: MarketData]
    ) -> EventLoopFuture<Void> {
        var badgeCountByDeviceToken: [String: Int] = [:]
        var deleteAlertFutures: [EventLoopFuture<Void>] = []
        
        for priceAlert in priceAlerts {
            guard let id = priceAlert.id,
                  let currentPrice = marketData[id]?.currentPrice,
                  let deviceToken = priceAlert.deviceToken else {
                continue
            }
            
            let meetsCondition = checkPriceCondition(for: priceAlert, currentPrice: currentPrice)
            
            if meetsCondition {
                let badgeCount = (badgeCountByDeviceToken[deviceToken] ?? 0) + 1
                badgeCountByDeviceToken[deviceToken] = badgeCount
                let sendNotificationFuture = sendPushNotification(
                    on: req,
                    for: priceAlert,
                    deviceToken: deviceToken,
                    badge: badgeCount
                )
                deleteAlertFutures.append(sendNotificationFuture.flatMap {
                    priceAlert.delete(on: req.db)
                })
            }
        }
        return EventLoopFuture<Void>.andAllSucceed(deleteAlertFutures, on: req.eventLoop)
    }
    
    private func checkPriceCondition(for priceAlert: PriceAlert, currentPrice: Double) -> Bool {
        switch priceAlert.targetDirection {
        case .above:
            return currentPrice >= priceAlert.targetPrice
        case .below:
            return currentPrice <= priceAlert.targetPrice
        }
    }
    
    private func sendPushNotification(
        on req: Request,
        for priceAlert: PriceAlert,
        deviceToken: String,
        badge: Int
    ) -> EventLoopFuture<Void> {
        let alert = APNSwiftAlert(
            title: "Price Alert",
            body: "Your price target of \(priceAlert.targetPrice)$ for \(priceAlert.name) is reached!"
        )
        let aps = APNSwiftPayload(alert: alert, badge: badge, sound: .normal("default"))
        let notification = PriceAlertNotification(id: priceAlert.id!, aps: aps)
        
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
