@testable import App
import XCTVapor

func assertCoinsEqual(_ coins: [Coin], _ expectedCoins: [Coin]) {
    XCTAssertEqual(coins.count, expectedCoins.count)
    for (index, _) in coins.enumerated() {
        let coin = coins[index]
        let expectedCoin = expectedCoins[index]
        XCTAssertEqual(coin, expectedCoin)
    }
}
