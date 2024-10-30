import Fluent

struct CreatePriceAlert: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("price_alerts")
            .field("id", .string, .required)
            .field("name", .string, .required)
            .field("target_price", .double, .required)
            .field("target_direction", .string, .required)
            .field("device_token", .string)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("price_alerts").delete()
    }
}
