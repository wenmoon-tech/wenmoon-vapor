import APNS

struct PriceAlertNotification: APNSwiftNotification {
    let id: String
    let aps: APNSwiftPayload
    
    init(id: String, aps: APNSwiftPayload) {
        self.id = id
        self.aps = aps
    }
}
