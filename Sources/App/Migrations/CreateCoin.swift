import Fluent

struct CreateCoin: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("coins")
            .field("id", .string, .required)
            .field("symbol", .string, .required)
            .field("name", .string, .required)
            .field("image", .string)
            .field("current_price", .double)
            .field("market_cap", .double)
            .field("market_cap_rank", .int64)
            .field("fully_diluted_valuation", .double)
            .field("total_volume", .double)
            .field("high_24h", .double)
            .field("low_24h", .double)
            .field("price_change_24h", .double)
            .field("price_change_percentage_24h", .double)
            .field("market_cap_change_24h", .double)
            .field("market_cap_change_percentage_24h", .double)
            .field("circulating_supply", .double)
            .field("total_supply", .double)
            .field("max_supply", .double)
            .field("ath", .double)
            .field("ath_change_percentage", .double)
            .field("ath_date", .string)
            .field("atl", .double)
            .field("atl_change_percentage", .double)
            .field("atl_date", .string)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("coins").delete()
    }
}
