import Vapor

struct CoinSearchResponse: Content {
    let coins: [Coin]
}
