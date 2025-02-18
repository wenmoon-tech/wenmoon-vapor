@testable import App
import XCTVapor

struct CoinFactoryMock {
    static func makeCoin(
        id: String = "coin-1",
        symbol: String = "C-1",
        name: String = "Coin 1",
        image: URL? = nil,
        currentPrice: Double? = .random(in: 0.01...100000),
        marketCap: Double? = .random(in: 1_000_000...1_000_000_000),
        marketCapRank: Int64? = .random(in: 1...1000),
        priceChangePercentage24H: Double? = .random(in: -50...50),
        circulatingSupply: Double? = .random(in: 1_000...1_000_000_000),
        ath: Double? = .random(in: 0.01...100000)
    ) -> Coin {
        .init(
            id: id,
            symbol: symbol,
            name: name,
            image: image,
            currentPrice: currentPrice,
            marketCap: marketCap,
            marketCapRank: marketCapRank,
            priceChangePercentage24H: priceChangePercentage24H,
            circulatingSupply: circulatingSupply,
            ath: ath
        )
    }
    
    static func makeCoins(count: Int = 10, at page: Int = 1) -> [Coin] {
        let startIndex = (page - 1) * count + 1
        return (startIndex..<startIndex + count).map { index in
            makeCoin(
                id: "coin-\(index)",
                name: "Coin \(index)",
                marketCapRank: Int64(index)
            )
        }
    }
}
