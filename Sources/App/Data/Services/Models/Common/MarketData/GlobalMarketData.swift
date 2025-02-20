import Vapor

struct GlobalMarketData: Content, Equatable {
    let cpiPercentage: Double
    let nextCPITimestamp: Int
    let interestRatePercentage: Double
    let nextFOMCMeetingTimestamp: Int
}
