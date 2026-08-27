import Foundation
import Combine
import UIKit

// MARK: - Image loading protocol
protocol ImageLoadingService {
    func load(url: URL) async throws -> UIImage
    func prefetch(urls: [URL])
}

// MARK: - Network service protocol
protocol WallpaperNetworkService {
    func fetchPopular(page: Int, perPage: Int) async throws -> PaginatedResponse<Wallpaper>
    func fetchSearch(query: String?, page: Int, perPage: Int) async throws -> PaginatedResponse<Wallpaper>
    func fetchCategory(slug: String, page: Int, perPage: Int) async throws -> PaginatedResponse<Wallpaper>
}

// MARK: - Pagination
struct PaginatedResponse<T: Sendable> {
    let totalResults: Int
    let page: Int
    let perPage: Int
    let results: [T]
    var hasNext: Bool { page * perPage < totalResults }
}

// MARK: - Persistence protocol (favorites + settings)
protocol PersistenceStore {
    var favorites: Set<String> { get async }
    var hasFavorited: (_ id: String) -> Bool { get }
    func toggleFavorite(_ id: String)
    var selectedTheme: AppTheme { get set }
    var blurMode: BlurMode { get set }
}

// MARK: - Theme

// MARK: - Blur mode
