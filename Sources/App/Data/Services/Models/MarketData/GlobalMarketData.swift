import Vapor

struct GlobalMarketData: Content {
    var cpiPercentage: Double
    var nextCPITimestamp: Int
    var interestRatePercentage: Double
    var nextFOMCMeetingTimestamp: Int
}
