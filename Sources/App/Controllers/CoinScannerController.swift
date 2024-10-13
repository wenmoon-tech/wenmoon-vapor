import Fluent
import APNS
import Vapor

struct CoinScannerController {

    func fetchCoins(on req: Request, currency: String = "usd", page: Int = 1, perPage: Int = 250) -> EventLoopFuture<Void> {
        var urlComponents = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")
        urlComponents?.queryItems = [
            URLQueryItem(name: "vs_currency", value: currency),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        
        guard let url = urlComponents?.url else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to create URL"))
        }

        var headers = HTTPHeaders()
        headers.add(name: "User-Agent", value: "VaporApp/1.0")

        let urlRequest = ClientRequest(method: .GET, url: URI(string: url.absoluteString), headers: headers)
        
        // Make the HTTP GET request
        return req.client.send(urlRequest).flatMap { response in
            guard response.status == .ok else {
                let errorMessage = "Failed to fetch coins: \(response.status)"
                print(errorMessage)
                return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: errorMessage))
            }
            
            guard let data = response.body else {
                return req.eventLoop.makeFailedFuture(Abort(.badRequest))
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do {
                let coins = try decoder.decode([Coin].self, from: Data(buffer: data))
                let dbUpserts = coins.map { coin in
                    return Coin.query(on: req.db)
                        .filter(\.$coinID == coin.coinID)
                        .first()
                        .flatMap { existingCoin in
                            if let existingCoin = existingCoin {
                                existingCoin.coinName = coin.coinName
                                existingCoin.coinImage = coin.coinImage
                                existingCoin.marketCapRank = coin.marketCapRank
                                existingCoin.currentPrice = coin.currentPrice
                                existingCoin.priceChangePercentage24H = coin.priceChangePercentage24H
                                return existingCoin.update(on: req.db)
                            } else {
                                return coin.create(on: req.db)
                            }
                        }
                }
                
                print("Fetched page \(page) with coins: \(coins.count)")
                return req.eventLoop.flatten(dbUpserts).transform(to: ())
            } catch {
                print(error)
                return req.eventLoop.makeFailedFuture(error)
            }
        }
    }
}
