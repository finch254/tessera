import Foundation

// MARK: - Pexels API client
final class PexelsNetworkService: WallpaperNetworkService {
    // To use: sign up at https://www.pexels.com/api/ and set this env var or constant.
    // The free tier allows 200 requests/min, 20,000/day. No key needed for basic
    // usage in some configurations — but Pexels recommends a key. Add yours here.
    private static let apiKey: String = {
        if let key = ProcessInfo.processInfo.environment["PEXELS_API_KEY"] {
            return key
        }
        // Fallback: anonymous public access (less reliable). Replace with your key for production.
        return ""
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    // MARK: - Public (editor's choice / featured)
    func fetchPopular(page: Int = 1, perPage: Int = 40) async throws -> PaginatedResponse<Wallpaper> {
        try await fetchSearch(query: nil, page: page, perPage: perPage)
    }

    // MARK: - Search
    func fetchSearch(query: String?, page: Int = 1, perPage: Int = 40) async throws -> PaginatedResponse<Wallpaper> {
        var urlComponents = URLComponents(string: "https://api.pexels.com/v1/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "orientation", value: "landscape"),
            URLQueryItem(name: "size", value: "large"),
        ]
        if let query = query, !query.isEmpty {
            urlComponents.queryItems?.append(URLQueryItem(name: "query", value: query))
        } else {
            // Editor's choice when no query
            urlComponents.queryItems?.append(URLQueryItem(name: "editor", value: "true"))
        }

        guard let url = urlComponents.url else {
            throw NetworkError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Authorization", forHTTPHeaderField: "Authorization")
        request.setValue(Self.apiKey, forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(PexelsSearchResponse.self, from: data)
        return decoded.toPaginated()
    }

    // MARK: - Category by slug (Pexels doesn't have a category endpoint directly;
    // we use search with the category as query. For categories with curated images,
    // you'd add a curated JSON list. This uses Pexels search.)
    func fetchCategory(slug: String, page: Int = 1, perPage: Int = 40) async throws -> PaginatedResponse<Wallpaper> {
        try await fetchSearch(query: slug, page: page, perPage: perPage)
    }
}

// MARK: - Pexels response models
struct PexelsSearchResponse: Decodable {
    let totalResults: Int
    let page: Int
    let perPage: Int
    let photos: [PexelsPhoto]

    func toPaginated() -> PaginatedResponse<Wallpaper> {
        PaginatedResponse(
            totalResults: totalResults,
            page: page,
            perPage: perPage,
            results: photos.map { $0.toWallpaper() }
        )
    }
}

struct PexelsPhoto: Decodable {
    let id: Int
    let photographer: String
    let photographerId: Int
    let width: Int
    let height: Int
    let avgColor: String?
    let alt: String?
    let liked: Bool?
    let src: [String: String]

    func toWallpaper() -> Wallpaper {
        Wallpaper(
            id: String(id),
            photographer: photographer,
            photographerId: String(photographerId),
            width: width,
            height: height,
            avgColor: avgColor,
            src: PexelsImageURLs(from: src),
            alt: alt,
            liked: liked
        )
    }
}

// MARK: - Errors
enum NetworkError: Error, LocalizedError {
    case badURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case noData

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code): return "HTTP \(code)"
        case .decodingError: return "Failed to decode response"
        case .noData: return "No data received"
        }
    }
}
