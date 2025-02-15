import Vapor

struct GlobalMarketData: Content {
    let cpiPercentage: Double
    let nextCPITimestamp: Int
    let interestRatePercentage: Double
    let nextFOMCMeetingTimestamp: Int
}
