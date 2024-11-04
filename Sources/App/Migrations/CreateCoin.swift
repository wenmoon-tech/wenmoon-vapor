import Fluent

struct CreateCoin: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("coins")
            .field("id", .string, .required)
            .field("name", .string, .required)
            .field("image", .string)
            .field("market_cap_rank", .int64)
            .field("current_price", .double)
            .field("price_change_percentage_24h", .double)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("coins").delete()
    }
}
