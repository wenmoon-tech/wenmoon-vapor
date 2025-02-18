import Vapor

protocol CoinScannerService {
    func fetchCoins(onPage page: Int64, perPage: Int64, currency: Currency, req: Request) -> EventLoopFuture<[Coin]>
    func fetchCoinDetails(for id: String, req: Request) -> EventLoopFuture<CoinDetails>
    func fetchChartData(for id: String, on timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]>
    func searchCoins(by query: String, req: Request) -> EventLoopFuture<[Coin]>
    func fetchMarketData(for ids: [String], currency: Currency, req: Request) -> EventLoopFuture<[String: MarketData]>
    func fetchGlobalCryptoMarketData(req: Request) -> EventLoopFuture<GlobalCryptoMarketData>
}

final class CoinScannerServiceImpl: BaseBackendService, CoinScannerService {
    // MARK: - Nested Types
    struct Cache<Value> {
        var value: Value
        var lastUpdatedAt: Date
        
        func isValid(ttl: TimeInterval) -> Bool {
            Date().timeIntervalSince(lastUpdatedAt) < ttl
        }
    }
    
    typealias CoinsCache = Cache<[Coin]>
    typealias SearchCache = Cache<[Coin]>
    typealias MarketDataCache = Cache<MarketData>
    typealias GlobalMarketDataCache = Cache<GlobalCryptoMarketData>
    typealias ChartDataCache = Cache<[Timeframe: [ChartData]]>
    typealias CoinDetailsCache = Cache<CoinDetails>
    
    // MARK: - Singleton
    static let shared = CoinScannerServiceImpl()
    private override init() {}
    
    // MARK: - Properties
    private var coinsCache: [Int64: CoinsCache] = [:]
    private let coinsTTL: TimeInterval = 30 * 60  // 30 minutes
    
    private var coinDetailsCache: [CoinDetailsCache] = []
    private let coinDetailsTTL: TimeInterval = 120 * 60  // 2 hours
    
    private var chartDataCache: [String: ChartDataCache] = [:]
    private let cacheTTL: [Timeframe: TimeInterval] = [
        .oneDay: 900,       // 15 minutes
        .oneWeek: 3600,     // 1 hour
        .oneMonth: 21600,   // 6 hours
        .yearToDate: 86400  // 1 day
    ]
    
    private var searchCache: [String: SearchCache] = [:]
    private let searchTTL: TimeInterval = 15 * 60  // 15 minutes
    
    private var marketDataCache: [String: MarketDataCache] = [:]
    private let marketDataTTL: TimeInterval = 3 * 60  // 3 minutes
    
    private var globalMarketDataCache: GlobalMarketDataCache?
    private let globalMarketDataTTL: TimeInterval = 120 * 60  // 2 hours
    
    // MARK: - Internal Methods
    func fetchCoins(onPage page: Int64, perPage: Int64, currency: Currency, req: Request) -> EventLoopFuture<[Coin]> {
        if let cache = coinsCache[page], cache.isValid(ttl: coinsTTL) {
            req.logger.info("Returning cached coins for page \(page)")
            return req.eventLoop.makeSucceededFuture(cache.value)
        }
        
        guard let uri = makeCoinsURI(currency: currency.rawValue, page: page, perPage: perPage) else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Invalid coins URI"))
        }
        
        req.logger.info("Fetching coins from CoinGecko for page \(page)")
        
        return req.client.get(uri, headers: makeHeaders())
            .flatMapThrowing { [unowned self] response in
                guard response.status == .ok, let body = response.body else {
                    throw Abort(.internalServerError, reason: "Failed to fetch coins: \(response.status)")
                }
                
                let coins = try decoder.decode([Coin].self, from: Data(buffer: body))
                coinsCache[page] = CoinsCache(value: coins, lastUpdatedAt: Date())
                
                return coins
            }
    }
    
    func fetchCoinDetails(for id: String, req: Request) -> EventLoopFuture<CoinDetails> {
        if let cached = coinDetailsCache.first(where: { $0.value.id == id }), cached.isValid(ttl: coinDetailsTTL) {
            req.logger.info("Returning cached coin details for coin ID: \(id)")
            return req.eventLoop.makeSucceededFuture(cached.value)
        }
        
        guard let uri = makeCoinDetailsURI(for: id) else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Invalid coin details URI"))
        }
        
        req.logger.info("Fetching coin details from Coingecko for coin ID: \(id)")
        
        return req.client.get(uri, headers: makeHeaders())
            .flatMapThrowing { [unowned self] response in
                guard response.status == .ok, let body = response.body else {
                    throw Abort(.internalServerError, reason: "Failed to fetch coin details: \(response.status)")
                }
                
                let coinDetails = try decoder.decode(CoinDetails.self, from: Data(buffer: body))
                if let index = coinDetailsCache.firstIndex(where: { $0.value.id == id }) {
                    coinDetailsCache[index].value = coinDetails
                    coinDetailsCache[index].lastUpdatedAt = Date()
                } else {
                    let cache = CoinDetailsCache(value: coinDetails, lastUpdatedAt: Date())
                    coinDetailsCache.append(cache)
                }
                
                return coinDetails
            }
    }
    
    func fetchChartData(for id: String, on timeframe: Timeframe, currency: Currency, req: Request) -> EventLoopFuture<[ChartData]> {
        if let cached = getCachedChartData(for: id, timeframe: timeframe) {
            return currency == .usd
            ? req.eventLoop.makeSucceededFuture(cached)
            : convertChartData(cached, to: currency, req: req)
        }
        
        guard let uri = makeChartDataURI(for: id, days: timeframe.rawValue) else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Invalid chart data URI"))
        }
        
        return req.client.get(uri, headers: makeHeaders())
            .flatMapThrowing { [unowned self] response in
                guard response.status == .ok, let body = response.body else {
                    throw Abort(.internalServerError, reason: "Failed to fetch chart data")
                }
                
                let data = Data(buffer: body)
                let chartResponse = try decoder.decode(ChartDataResponse.self, from: data)
                let chartData = chartResponse.prices.compactMap { entry -> ChartData? in
                    guard entry.count == 2 else { return nil }
                    let timestamp = Int(entry[0] / 1000)
                    let close = entry[1]
                    return ChartData(timestamp: timestamp, close: close)
                }
                
                cacheChartData(chartData, for: id, timeframe: timeframe)
                return chartData
            }
            .flatMap { [unowned self] chartData in
                (currency == .usd) ? req.eventLoop.makeSucceededFuture(chartData) : convertChartData(chartData, to: currency, req: req)
            }
    }
    
    func searchCoins(by query: String, req: Request) -> EventLoopFuture<[Coin]> {
        if let cached = searchCache[query], cached.isValid(ttl: searchTTL) {
            req.logger.info("Returning cached search results for query: \(query)")
            return req.eventLoop.makeSucceededFuture(cached.value)
        }
        
        guard let uri = makeSearchURI(query: query) else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Invalid search URI"))
        }
        
        req.logger.info("Fetching search results from Coingecko for query: \(query)")
        
        return req.client.get(uri, headers: makeHeaders())
            .flatMapThrowing { [unowned self] response in
                guard response.status == .ok, let body = response.body else {
                    throw Abort(.internalServerError, reason: "Failed to fetch search results: \(response.status)")
                }
                
                let data = Data(buffer: body)
                let searchResponse = try decoder.decode(CoinSearchResponse.self, from: data)
                let coins = searchResponse.coins
                searchCache[query] = SearchCache(value: coins, lastUpdatedAt: Date())
                
                return coins
            }
            .flatMap { [unowned self] coins in
                let ids = coins.compactMap { $0.id }
                return fetchMarketData(for: ids, currency: .usd, req: req).map { marketDataDict in
                    coins.forEach { coin in
                        if let marketData = marketDataDict[coin.id!] {
                            coin.updateMarketData(with: marketData)
                        }
                    }
                    return coins
                }
            }
    }
    
    func fetchMarketData(for ids: [String], currency: Currency, req: Request) -> EventLoopFuture<[String: MarketData]> {
        var validCache: [String: MarketData] = [:]
        var missingIDs: [String] = []
        
        for id in ids {
            if let cache = marketDataCache[id], cache.isValid(ttl: marketDataTTL) {
                validCache[id] = cache.value
            } else {
                marketDataCache.removeValue(forKey: id)
                missingIDs.append(id)
            }
        }
        
        if missingIDs.isEmpty {
            req.logger.info("Returning cached market data for all requested coins")
            return req.eventLoop.makeSucceededFuture(validCache)
        }
        
        let idsString = missingIDs.joined(separator: ",")
        guard let uri = makePriceURI(ids: idsString, currency: currency.rawValue) else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Invalid price URI"))
        }
        
        req.logger.info("Fetching fresh market data from Coingecko for coin IDs: \(idsString)")
        
        return req.client.get(uri, headers: makeHeaders())
            .flatMapThrowing { [unowned self] response in
                guard response.status == .ok, let body = response.body else {
                    throw Abort(.internalServerError, reason: "Failed to fetch market data: \(response.status)")
                }
                
                let data = Data(buffer: body)
                let rawData = try decoder.decode([String: [String: Double?]].self, from: data)
                var fetchedData: [String: MarketData] = [:]
                
                for id in missingIDs {
                    if let dict = rawData[id] {
                        let processedDict = dict.compactMapValues { $0 }
                        let marketData = MarketData(
                            currentPrice: processedDict[currency.rawValue] ?? .zero,
                            marketCap: processedDict["\(currency)_market_cap"],
                            priceChangePercentage24H: processedDict["\(currency)_24h_change"]
                        )
                        marketDataCache[id] = MarketDataCache(value: marketData, lastUpdatedAt: Date())
                        fetchedData[id] = marketData
                    }
                }
                
                let result = validCache.merging(fetchedData) { (_, new) in new }
                return result
            }
    }
    
    func fetchGlobalCryptoMarketData(req: Request) -> EventLoopFuture<GlobalCryptoMarketData> {
        if let cache = globalMarketDataCache, cache.isValid(ttl: globalMarketDataTTL) {
            req.logger.info("Returning cached global market data.")
            return req.eventLoop.makeSucceededFuture(cache.value)
        }
        
        guard let uri = makeGlobalMarketDataURI() else {
            return req.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Invalid global market data URI"))
        }
        
        req.logger.info("Fetching global market data from Coingecko.")
        
        return req.client.get(uri, headers: makeHeaders())
            .flatMapThrowing { [unowned self] response in
                guard response.status == .ok, let body = response.body else {
                    throw Abort(.internalServerError, reason: "Failed to fetch global market data: \(response.status)")
                }
                
                let globalResponse = try decoder.decode(GlobalCryptoMarketDataResponse.self, from: Data(buffer: body))
                let globalData = GlobalCryptoMarketData(marketCapPercentage: globalResponse.data.marketCapPercentage)
                globalMarketDataCache = GlobalMarketDataCache(value: globalData, lastUpdatedAt: Date())
                
                return globalData
            }
    }
    
    // MARK: - Private Methods
    private func makeHeaders() -> HTTPHeaders {
        var headers = HTTPHeaders()
        headers.add(name: .userAgent, value: "VaporApp/1.0")
        headers.add(name: .accept, value: "application/json")
        headers.add(name: "x-cg-demo-api-key", value: "CG-QAWEu4NebmGxZFmGVWrQPYwT")
        return headers
    }
    
    private func makeCoinsURI(currency: String, page: Int64, perPage: Int64) -> URI? {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")
        components?.queryItems = [
            URLQueryItem(name: "vs_currency", value: currency),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        guard let urlString = components?.url?.absoluteString else { return nil }
        return URI(string: urlString)
    }
    
    private func makeSearchURI(query: String) -> URI? {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/search")
        components?.queryItems = [
            URLQueryItem(name: "query", value: query)
        ]
        guard let urlString = components?.url?.absoluteString else { return nil }
        return URI(string: urlString)
    }
    
    private func makePriceURI(ids: String, currency: String) -> URI? {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")
        components?.queryItems = [
            URLQueryItem(name: "ids", value: ids),
            URLQueryItem(name: "vs_currencies", value: currency),
            URLQueryItem(name: "include_market_cap", value: "true"),
            URLQueryItem(name: "include_24hr_vol", value: "true"),
            URLQueryItem(name: "include_24hr_change", value: "true")
        ]
        guard let urlString = components?.url?.absoluteString else { return nil }
        return URI(string: urlString)
    }
    
    private func makeGlobalMarketDataURI() -> URI? {
        guard let urlString = URL(string: "https://api.coingecko.com/api/v3/global")?.absoluteString else {
            return nil
        }
        return URI(string: urlString)
    }
    
    private func makeChartDataURI(for id: String, days: String) -> URI? {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/\(id)/market_chart")
        components?.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "days", value: days)
        ]
        guard let urlString = components?.url?.absoluteString else {
            return nil
        }
        return URI(string: urlString)
    }
    
    private func makeCoinDetailsURI(for id: String) -> URI? {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/\(id)")
        components?.queryItems = [URLQueryItem(name: "developer_data", value: "false"),]
        guard let urlString = components?.url?.absoluteString else { return nil }
        return URI(string: urlString)
    }
    
    private func getCachedChartData(for id: String, timeframe: Timeframe) -> [ChartData]? {
        guard let cached = chartDataCache[id],
              let ttl = cacheTTL[timeframe],
              let chartData = cached.value[timeframe],
              Date().timeIntervalSince(cached.lastUpdatedAt) < ttl else {
            return nil
        }
        return chartData
    }
    
    private func cacheChartData(_ chartData: [ChartData], for id: String, timeframe: Timeframe) {
        let now = Date()
        if chartDataCache[id] == nil {
            chartDataCache[id] = ChartDataCache(value: [:], lastUpdatedAt: now)
        }
        chartDataCache[id]?.value[timeframe] = chartData
        chartDataCache[id]?.lastUpdatedAt = now
    }
    
    private func convertChartData(_ data: [ChartData], to currency: Currency, req: Request) -> EventLoopFuture<[ChartData]> {
        guard currency != .usd else {
            return req.eventLoop.makeSucceededFuture(data)
        }
        return fetchConversionRate(from: .usd, to: currency, req: req).map { rate in
            data.map { ChartData(timestamp: $0.timestamp, close: $0.close * rate) }
        }
    }
    
    private func fetchConversionRate(from: Currency, to: Currency, req: Request) -> EventLoopFuture<Double> {
        let rates: [Currency: Double] = [.usd: 1, .eur: 0.85, .gbp: 0.75]
        guard let rate = rates[to] else {
            return req.eventLoop.makeFailedFuture(Abort(.badRequest, reason: "Unsupported currency \(to.rawValue)"))
        }
        return req.eventLoop.makeSucceededFuture(rate)
    }
}
