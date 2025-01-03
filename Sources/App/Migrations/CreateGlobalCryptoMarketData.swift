import Fluent

struct CreateGlobalCryptoMarketData: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("global_crypto_market_data")
            .id()
            .field("market_cap_percentage", .dictionary, .required)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("global_crypto_market_data").delete()
    }
}
