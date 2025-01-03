import Fluent

struct CreateGlobalMarketData: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("global_market_data")
            .id()
            .field("cpi_percentage", .double, .required)
            .field("next_cpi_timestamp", .int, .required)
            .field("interest_rate_percentage", .double, .required)
            .field("next_fomc_meeting_timestamp", .int, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("global_market_data").delete()
    }
}
