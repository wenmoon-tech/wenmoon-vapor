import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    let databaseName: String
    let databasePort: Int

    if app.environment == .testing {
        databaseName = "vapor-test"
        databasePort = 5433
    } else {
        databaseName = Environment.get("DATABASE_NAME") ?? "vapor_database"
        databasePort = Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber
    }

    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: databasePort,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: databaseName
    ), as: .psql)

    app.migrations.add(CreatePriceAlert())

    // register routes
    try routes(app)
}
