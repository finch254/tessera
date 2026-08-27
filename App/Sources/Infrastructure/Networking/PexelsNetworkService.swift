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
        return "MJC9rZdQt8kfrOEzbKCvk0ODBqovZLkgxWxPuXmne332mImCiWbWOPdN"
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    func fetchPopular(page: Int = 1, perPage: Int = 40) async throws -> PaginatedResponse<Wallpaper> {
        var urlComponents = URLComponents(string: "https://api.pexels.com/v1/curated")!
        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
        ]
        return try await fetch(urlComponents: urlComponents)
    }

    func fetchSearch(query: String?, page: Int = 1, perPage: Int = 40) async throws -> PaginatedResponse<Wallpaper> {
        var urlComponents = URLComponents(string: "https://api.pexels.com/v1/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "orientation", value: "landscape"),
            URLQueryItem(name: "size", value: "large"),
        ]
        if let query, !query.isEmpty {
            urlComponents.queryItems?.append(URLQueryItem(name: "query", value: query))
        }
        return try await fetch(urlComponents: urlComponents)
    }

    func fetchCategory(slug: String, page: Int = 1, perPage: Int = 40) async throws -> PaginatedResponse<Wallpaper> {
        var urlComponents = URLComponents(string: "https://api.pexels.com/v1/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "orientation", value: "landscape"),
            URLQueryItem(name: "size", value: "large"),
            URLQueryItem(name: "query", value: slug),
        ]
        return try await fetch(urlComponents: urlComponents)
    }

    private func fetch(urlComponents: URLComponents) async throws -> PaginatedResponse<Wallpaper> {
        guard let url = urlComponents.url else {
            throw NetworkError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
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
}

// MARK: - Pexels response models
struct PexelsSearchResponse: Decodable {
    let totalResults: Int
    let page: Int
    let perPage: Int
    let photos: [PexelsPhoto]

    enum CodingKeys: String, CodingKey {
        case totalResults = "total_results"
        case page
        case perPage = "per_page"
        case photos
    }

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
    let src: [String: Any]

    enum CodingKeys: String, CodingKey {
        case id
        case photographer
        case photographerId = "photographer_id"
        case width
        case height
        case avgColor = "avg_color"
        case alt
        case liked
        case src
    }

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
