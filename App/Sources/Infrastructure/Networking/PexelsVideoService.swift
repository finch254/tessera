import Foundation

// MARK: - Pexels Videos API client
protocol WallpaperVideoNetworkService {
    func fetchPopularVideos(page: Int, perPage: Int) async throws -> PexelsVideoResponse
    func fetchVideoSearch(query: String, page: Int, perPage: Int) async throws -> PexelsVideoResponse
}

final class PexelsVideoService: WallpaperVideoNetworkService {
    private static let apiKey: String = {
        if let key = ProcessInfo.processInfo.environment["PEXELS_API_KEY"] {
            return key
        }
        return "MJC9rZdQt8kfrOEzbKCvk0ODBqovZLkgxWxPuXmne332mImCiWbWOPdN"
    }()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    func fetchPopularVideos(page: Int = 1, perPage: Int = 30) async throws -> PexelsVideoResponse {
        var urlComponents = URLComponents(string: "https://api.pexels.com/videos/popular")!
        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "orientation", value: "portrait"),
        ]
        return try await fetch(urlComponents: urlComponents)
    }

    func fetchVideoSearch(query: String, page: Int = 1, perPage: Int = 30) async throws -> PexelsVideoResponse {
        var urlComponents = URLComponents(string: "https://api.pexels.com/videos/search")!
        urlComponents.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "orientation", value: "portrait"),
            URLQueryItem(name: "query", value: query),
        ]
        return try await fetch(urlComponents: urlComponents)
    }

    private func fetch(urlComponents: URLComponents) async throws -> PexelsVideoResponse {
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

        return try JSONDecoder().decode(PexelsVideoResponse.self, from: data)
    }
}

// MARK: - Video downloader
final class VideoDownloader {
    static let shared = VideoDownloader()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        return URLSession(configuration: config)
    }()

    /// Downloads a video file to the caches directory. Returns the local URL.
    func download(_ file: VideoFile, progress: ((Double) -> Void)? = nil) async throws -> URL {
        let destDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VideoWallpapers", isDirectory: true)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let dest = destDir.appendingPathComponent("\(file.id)_\(file.width)x\(file.height).mp4")
        if FileManager.default.fileExists(atPath: dest.path) {
            return dest
        }

        let (tempURL, response) = try await session.download(from: file.link)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NetworkError.invalidResponse
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        progress?(1.0)
        return dest
    }
}
