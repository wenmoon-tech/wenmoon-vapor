import Fluent

struct CreatePriceAlert: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("price_alerts")
            .field("id", .string, .required)
            .field("symbol", .string, .required)
            .field("target_price", .double, .required)
            .field("target_direction", .string, .required)
            .field("user_id", .string, .required)
            .field("device_token", .string, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("price_alerts").delete()
    }
}
