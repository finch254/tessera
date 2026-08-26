import Foundation
import Combine

// MARK: - Image loading protocol
protocol ImageLoadingService {
    func load(url: URL) async throws -> UIImage
    func prefetch(urls: [URL])
}

// MARK: - Network service protocol
protocol WallpaperNetworkService {
    func fetchPopular(page: Int, perPage: Int) async throws -> PaginatedResponse<Wallpaper>
    func fetchSearch(query: String, page: Int, perPage: Int) async throws -> PaginatedResponse<Wallpaper>
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
    var favorites: Set<String> { get async set }
    var hasFavorited: (_ id: String) -> Bool { get }
    func toggleFavorite(_ id: String)
    var selectedTheme: AppTheme { get set }
    var blurMode: BlurMode { get set }
}

// MARK: - Theme
enum AppTheme: String, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case amoled = "AMOLED"

    var colorScheme: ColorScheme? { self == .system ? nil : (self == .dark || self == .amoled ? .dark : .light) }
}

// MARK: - Blur mode
enum BlurMode: String, CaseIterable, Sendable {
    case gaussian = "Gaussian"
    case box = "Box"
    case median = "Median"

    var filterName: String {
        switch self {
        case .gaussian: return "CIGaussianBlur"
        case .box: return "CIBoxBlur"
        case .median: return "CIMedianFilter"
        }
    }
}
