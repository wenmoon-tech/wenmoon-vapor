import Vapor

extension CoinDetails {
    struct Links: Content, Equatable {
        // MARK: - Nested Types
        struct ReposURL: Content, Equatable {
            let github: [URL]?
        }
        
        // MARK: - Properties
        let homepage: [URL]?
        let whitepaper: URL?
        let blockchainSite: [URL]?
        let chatUrl: [URL]?
        let announcementUrl: [URL]?
        let twitterScreenName: String?
        let telegramChannelIdentifier: String?
        let subredditUrl: URL?
        let reposUrl: ReposURL
        
        // MARK: - Initializer
        init(
            homepage: [URL]?,
            whitepaper: URL?,
            blockchainSite: [URL]?,
            chatUrl: [URL]?,
            announcementUrl: [URL]?,
            twitterScreenName: String?,
            telegramChannelIdentifier: String?,
            subredditUrl: URL?,
            reposUrl: ReposURL
        ) {
            self.homepage = homepage
            self.whitepaper = whitepaper
            self.blockchainSite = blockchainSite
            self.chatUrl = chatUrl
            self.announcementUrl = announcementUrl
            self.twitterScreenName = twitterScreenName
            self.telegramChannelIdentifier = telegramChannelIdentifier
            self.subredditUrl = subredditUrl
            self.reposUrl = reposUrl
        }
        
        // MARK: - Codable
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            homepage = container.decodeSafeURLArray(forKey: .homepage)
            whitepaper = container.decodeSafeURL(forKey: .whitepaper)
            blockchainSite = container.decodeSafeURLArray(forKey: .blockchainSite)
            chatUrl = container.decodeSafeURLArray(forKey: .chatUrl)
            announcementUrl = container.decodeSafeURLArray(forKey: .announcementUrl)
            twitterScreenName = try container.decodeIfPresent(String.self, forKey: .twitterScreenName)
            telegramChannelIdentifier = try container.decodeIfPresent(String.self, forKey: .telegramChannelIdentifier)
            subredditUrl = container.decodeSafeURL(forKey: .subredditUrl)
            reposUrl = try container.decode(ReposURL.self, forKey: .reposUrl)
        }
    }
}
