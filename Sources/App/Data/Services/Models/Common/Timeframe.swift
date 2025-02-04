import Vapor

enum Timeframe: String, Content, CaseIterable {
    case oneDay = "1"
    case oneWeek = "7"
    case oneMonth = "31"
    case yearToDate = "365"
}
