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

    let keyPath = "/Users/artkachenko/Desktop/Developer/My projects/Keys/AuthKey_2Q872WQ32R.p8"
    app.apns.configuration = try .init(authenticationMethod: .jwt(key: .private(filePath: keyPath),
                                                                  keyIdentifier: "2Q872WQ32R",
                                                                  teamIdentifier: "4H24ZTYPFZ"),
                                       topic: "arturtkachenko.WenMoon",
                                       environment: .sandbox)

    _ = app.eventLoopGroup.next().scheduleRepeatedAsyncTask(initialDelay: .seconds(60),
                                                            delay: .seconds(60)) { task -> EventLoopFuture<Void> in
        let controller = PriceAlertController()
        let request = Request(application: app, logger: app.logger, on: app.eventLoopGroup.next())
        return controller.checkPriceForAlerts(on: request)
    }

    // register routes
    try routes(app)
}
