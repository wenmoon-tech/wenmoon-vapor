import NIOSSL
import JWTKit
import Fluent
import FluentPostgresDriver
import APNS
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    if let databaseURL = Environment.get("DATABASE_URL"),
       var postgresConfig = PostgresConfiguration(url: databaseURL) {
        postgresConfig.tlsConfiguration = .makeClientConfiguration()
        postgresConfig.tlsConfiguration?.certificateVerification = .none
        app.databases.use(.postgres(configuration: postgresConfig), as: .psql)
    } else {
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
    }

    app.migrations.add(CreatePriceAlert())

    // register routes
    try routes(app)

    // register for sending push notifications
    try configureAPNS(app)

    // schedule price check for saved alerts
    schedulePriceCheck(app)
}

private func configureAPNS(_ app: Application) throws {
    let key: ECDSAKey

    if let keyContent = Environment.get("APNS_KEY") {
        key = try .private(pem: keyContent)
    } else {
        let keyPath = "/Users/artkachenko/Desktop/Developer/My projects/Keys/AuthKey_2Q872WQ32R.p8"
        key = try .private(filePath: keyPath)
    }

    let keyID = Environment.get("KEY_ID") ?? "2Q872WQ32R"
    let teamID = Environment.get("TEAM_ID") ?? "4H24ZTYPFZ"
    app.apns.configuration = .init(authenticationMethod: .jwt(key: key,
                                                              keyIdentifier: .init(string: keyID),
                                                              teamIdentifier: teamID),
                                   topic: "arturtkachenko.WenMoon",
                                   environment: .sandbox)
}

private func schedulePriceCheck(_ app: Application) {
    _ = app.eventLoopGroup.next().scheduleRepeatedAsyncTask(initialDelay: .seconds(180),
                                                            delay: .seconds(180)) { task -> EventLoopFuture<Void> in
        let controller = PriceAlertController()
        let request = Request(application: app, logger: app.logger, on: app.eventLoopGroup.next())
        return controller.checkPriceForAlerts(on: request)
    }
}
