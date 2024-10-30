import Fluent

struct CreateCoin: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("coins")
            .field("id", .string, .required)
            .field("name", .string, .required)
            .field("image_data", .data)
            .field("market_cap_rank", .int64, .required)
            .field("current_price", .double, .required)
            .field("price_change", .double, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("coins").delete()
    }
}
