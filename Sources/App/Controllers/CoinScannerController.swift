import Fluent
import APNS
import Vapor

struct CoinScannerController {
    func fetchCoins(
        on req: Request,
        currency: String = "usd",
        page: Int = 1,
        perPage: Int = 250
    ) -> EventLoopFuture<Void> {
        guard let url = makeCoinsURL(currency: currency, page: page, perPage: perPage) else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to create URL"))
        }
        
        let headers = HTTPHeaders([("User-Agent", "VaporApp/1.0")])
        let urlRequest = ClientRequest(method: .GET, url: URI(string: url.absoluteString), headers: headers)
        
        return req.client.send(urlRequest)
            .flatMap { response in
                guard response.status == .ok, let data = response.body else {
                    let errorMessage = "Failed to fetch coins: \(response.status)"
                    return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: errorMessage))
                }
                return self.processCoinsData(data, on: req, page: page)
            }
    }
    
    private func makeCoinsURL(currency: String, page: Int, perPage: Int) -> URL? {
        var urlComponents = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")
        urlComponents?.queryItems = [
            URLQueryItem(name: "vs_currency", value: currency),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        return urlComponents?.url
    }
    
    private func processCoinsData(_ data: ByteBuffer, on req: Request, page: Int) -> EventLoopFuture<Void> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let coins = try decoder.decode([CoinResponse].self, from: Data(buffer: data))
            let dbUpserts = coins.map { coin in
                return Coin.query(on: req.db)
                    .filter(\.$id == coin.id)
                    .first()
                    .flatMap { existingCoin in
                        let marketCapRank = coin.marketCapRank ?? .max
                        let currentPrice = coin.currentPrice ?? .zero
                        let priceChange = coin.priceChangePercentage24H ?? .zero
                        
                        if let existingCoin = existingCoin {
                            existingCoin.marketCapRank = marketCapRank
                            existingCoin.currentPrice = currentPrice
                            existingCoin.priceChange = priceChange
                            return existingCoin.update(on: req.db)
                        } else {
                            print("New coin: \(coin.id)")
                            return fetchImageData(for: coin, on: req).flatMap { imageData in
                                let newCoin = Coin()
                                newCoin.id = coin.id
                                newCoin.name = coin.name
                                newCoin.imageData = imageData
                                newCoin.marketCapRank = marketCapRank
                                newCoin.currentPrice = currentPrice
                                newCoin.priceChange = priceChange
                                return newCoin.create(on: req.db)
                            }
                        }
                    }
            }
            print("Fetched page \(page) with coins: \(coins.count)")
            return req.eventLoop.flatten(dbUpserts).transform(to: ())
        } catch {
            return req.eventLoop.makeFailedFuture(error)
        }
    }
    
    private func fetchImageData(for coin: CoinResponse, on req: Request) -> EventLoopFuture<Data?> {
        if let imageURL = coin.image {
            return loadImage(from: imageURL, on: req)
        } else {
            return req.eventLoop.makeSucceededFuture(nil)
        }
    }
    
    private func loadImage(from url: String, on req: Request) -> EventLoopFuture<Data?> {
        req.client.get(URI(string: url)).flatMapThrowing { response in
            guard response.status == .ok, let body = response.body else {
                throw Abort(.internalServerError, reason: "Failed to load image")
            }
            return Data(buffer: body)
        }
    }
}
