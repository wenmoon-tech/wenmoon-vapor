import APNS

struct PriceAlertNotification: APNSwiftNotification {
    let id: String
    let aps: APNSwiftPayload
}
