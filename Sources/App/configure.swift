import NIOSSL
import Fluent
import FluentPostgresDriver
import APNS
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

    // register for sending push notifications
    try configureAPNS(app)

    // schedule price check for saved alerts
    schedulePriceCheck(app)
}

private func configureAPNS(_ app: Application) throws {
    guard let apnsKey = Environment.get("APNS_KEY"),
          let keyID = Environment.get("KEY_ID"),
          let teamID = Environment.get("TEAM_ID") else { return }
    app.apns.configuration = try .init(authenticationMethod: .jwt(key: .private(pem: apnsKey),
                                                                  keyIdentifier: .init(string: keyID),
                                                                  teamIdentifier: teamID),
                                       topic: "arturtkachenko.WenMoon",
                                       environment: .sandbox)
}

private func schedulePriceCheck(_ app: Application) {
    _ = app.eventLoopGroup.next().scheduleRepeatedAsyncTask(initialDelay: .seconds(60),
                                                            delay: .seconds(60)) { task -> EventLoopFuture<Void> in
        let controller = PriceAlertController()
        let request = Request(application: app, logger: app.logger, on: app.eventLoopGroup.next())
        return controller.checkPriceForAlerts(on: request)
    }
}
