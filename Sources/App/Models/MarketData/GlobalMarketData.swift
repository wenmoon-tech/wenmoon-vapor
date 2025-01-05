import Vapor
import Fluent

final class GlobalMarketData: Model, Content {
    static let schema = "global_market_data"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "cpi_percentage")
    var cpiPercentage: Double
    
    @Field(key: "next_cpi_timestamp")
    var nextCPITimestamp: Int
    
    @Field(key: "interest_rate_percentage")
    var interestRatePercentage: Double
    
    @Field(key: "next_fomc_meeting_timestamp")
    var nextFOMCMeetingTimestamp: Int
    
    init() { }
    
    init(
        id: UUID? = nil,
        cpiPercentage: Double,
        nextCPITimestamp: Int,
        interestRatePercentage: Double,
        nextFOMCMeetingTimestamp: Int
    ) {
        self.cpiPercentage = cpiPercentage
        self.nextCPITimestamp = nextCPITimestamp
        self.interestRatePercentage = interestRatePercentage
        self.nextFOMCMeetingTimestamp = nextFOMCMeetingTimestamp
    }
}
