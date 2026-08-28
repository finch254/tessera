import Foundation

// MARK: - Video wallpaper model (Pexels Videos API)
struct VideoFile: Codable, Equatable {
    let id: Int
    let quality: String
    let fileType: String
    let width: Int
    let height: Int
    let link: URL

    enum CodingKeys: String, CodingKey {
        case id, quality, width, height, link
        case fileType = "file_type"
    }
}

struct VideoWallpaper: Codable, Identifiable, Equatable {
    let id: Int
    let width: Int
    let height: Int
    let duration: Int
    let image: URL?
    let videoFiles: [VideoFile]
    let user: PexelsUser?

    enum CodingKeys: String, CodingKey {
        case id, width, height, duration, image, user
        case videoFiles = "video_files"
    }

    var photographer: String { user?.name ?? "Pexels" }

    /// Best file for wallpaper use: HD, portrait-ish, capped at 1080p to keep
    /// Live Photo conversion and CAML generation fast and small.
    var bestFile: VideoFile? {
        let candidates = videoFiles
            .filter { $0.fileType.contains("mp4") }
            .filter { $0.width <= 1080 && $0.height <= 1920 }
            .sorted { ($0.width * $0.height) > ($1.width * $1.height) }
        return candidates.first ?? videoFiles.first
    }

    /// Smaller file for quick preview downloads.
    var previewFile: VideoFile? {
        videoFiles
            .filter { $0.fileType.contains("mp4") && $0.width <= 540 }
            .sorted { ($0.width * $0.height) > ($1.width * $1.height) }
            .first ?? bestFile
    }
}

struct PexelsUser: Codable, Equatable {
    let name: String
}

struct PexelsVideoResponse: Codable {
    let page: Int
    let perPage: Int
    let totalResults: Int
    let videos: [VideoWallpaper]

    enum CodingKeys: String, CodingKey {
        case page, videos, totalResults = "total_results", perPage = "per_page"
    }

    var hasNext: Bool { page * perPage < totalResults }
}

extension PaginatedResponse where T == VideoWallpaper {
    init(_ response: PexelsVideoResponse) {
        self.init(
            totalResults: response.totalResults,
            page: response.page,
            perPage: response.perPage,
            results: response.videos
        )
    }
}
