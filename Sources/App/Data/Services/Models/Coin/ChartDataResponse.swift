import Vapor

struct ChartDataResponse: Content {
    let prices: [[Double]]
}
