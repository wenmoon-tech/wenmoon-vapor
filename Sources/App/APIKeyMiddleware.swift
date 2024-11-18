import Vapor

struct APIKeyMiddleware: Middleware {
    let validKey: String

    init(validKey: String = Environment.get("API_KEY") ?? "9178693a7845b10ce1cedfe571f0682b9051aa793c41545739ce724f3ae272db") {
        self.validKey = validKey
    }

    func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        guard let apiKey = request.headers["X-API-Key"].first, apiKey == validKey else {
            return request.eventLoop.makeFailedFuture(Abort(.unauthorized, reason: "Invalid API Key"))
        }
        return next.respond(to: request)
    }
}
