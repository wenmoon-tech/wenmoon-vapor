import Foundation

enum Timeframe: String, CaseIterable, Decodable {
    case oneDay = "1d"
    case oneWeek = "1w"
    case oneMonth = "1M"
    case oneYear = "1y"
    case all = "all"
}
