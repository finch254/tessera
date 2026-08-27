import Foundation

// MARK: - Telegram sync service
final class TelegramSyncService: WallpaperNetworkService {
    private let baseURL: String
    private let session: URLSession

    init(baseURL: String = "") {
        if baseURL.isEmpty {
            #if DEBUG
            self.baseURL = "http://localhost:8787"
            #else
            self.baseURL = "https://tessera-telegram-sync.finchlord.workers.dev"
            #endif
        } else {
            self.baseURL = baseURL
        }
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Public

    func fetchPopular(page: Int = 1, perPage: Int = 40) async throws -> PaginatedResponse<Wallpaper> {
        try await fetchTelegramWallpapers(page: page, perPage: perPage)
    }

    func fetchSearch(query: String?, page: Int = 1, perPage: Int = 40) async throws -> PaginatedResponse<Wallpaper> {
        try await fetchTelegramWallpapers(page: page, perPage: perPage)
    }

    func fetchCategory(slug: String, page: Int = 1, perPage: Int = 40) async throws -> PaginatedResponse<Wallpaper> {
        try await fetchTelegramWallpapers(page: page, perPage: perPage)
    }

    // MARK: - Private

    private func fetchTelegramWallpapers(page: Int, perPage: Int) async throws -> PaginatedResponse<Wallpaper> {
        guard var components = URLComponents(string: baseURL) else {
            throw NetworkError.badURL
        }
        components.queryItems = [
            URLQueryItem(name: "channel", value: "@tessera_wallpapers"),
            URLQueryItem(name: "limit", value: String(perPage)),
        ]

        guard let url = components.url else {
            throw NetworkError.badURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let telegramResponse = try decoder.decode(TelegramSyncResponse.self, from: data)

        return PaginatedResponse(
            totalResults: telegramResponse.wallpapers.count,
            page: page,
            perPage: perPage,
            results: telegramResponse.wallpapers.map { $0.toWallpaper() }
        )
    }
}

// MARK: - Telegram sync response models
struct TelegramSyncResponse: Decodable {
    let source: String
    let channel: String
    let count: Int
    let wallpapers: [TelegramWallpaper]
}

struct TelegramWallpaper: Decodable {
    let id: String
    let title: String
    let photographer: String
    let category: String
    let width: Int
    let height: Int
    let fileId: String
    let url: String
    let date: String

    func toWallpaper() -> Wallpaper {
        let imageURLs = PexelsImageURLs(
            from: [
                "large": url,
                "medium": url,
                "small": url,
            ]
        )
        return Wallpaper(
            id: id,
            photographer: photographer,
            photographerId: "",
            width: width,
            height: height,
            avgColor: nil,
            src: imageURLs,
            alt: title,
            liked: false
        )
    }
}
