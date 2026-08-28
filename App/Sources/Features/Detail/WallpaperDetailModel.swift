import UIKit

// MARK: - Detail model
@MainActor
final class WallpaperDetailModel: ObservableObject {
    let wallpaper: Wallpaper?
    let videoWallpaper: VideoWallpaper?
    private let imageLoader: ImageLoadingService
    private let persistence: PersistenceStore

    var isVideo: Bool { videoWallpaper != nil }

    var displayTitle: String {
        videoWallpaper?.photographer ?? wallpaper?.photographer ?? ""
    }

    var displayImageURL: URL? {
        if let vw = videoWallpaper {
            return vw.image
        }
        return wallpaper?.src.large
    }

    var bestVideoFile: VideoFile? {
        videoWallpaper?.bestFile
    }

    // Sync accessors backed by the sync PersistenceStore properties
    var blurMode: BlurMode {
        get { persistence.blurMode }
        set { persistence.blurMode = newValue }
    }

    var isFavorited: Bool {
        let id = videoWallpaper?.id.description ?? wallpaper?.id ?? ""
        return persistence.hasFavorited(id)
    }

    // Convenience init for static images
    convenience init(wallpaper: Wallpaper,
                     persistence: PersistenceStore = UserDefaultsPersistenceStore()) {
        let loader = KingfisherImageLoader()
        self.init(wallpaper: wallpaper, videoWallpaper: nil, imageLoader: loader, persistence: persistence)
    }

    // Convenience init for videos
    convenience init(videoWallpaper: VideoWallpaper,
                     persistence: PersistenceStore = UserDefaultsPersistenceStore()) {
        let loader = KingfisherImageLoader()
        self.init(wallpaper: nil, videoWallpaper: videoWallpaper, imageLoader: loader, persistence: persistence)
    }

    // Full init for testability
    init(wallpaper: Wallpaper? = nil,
         videoWallpaper: VideoWallpaper? = nil,
         imageLoader: ImageLoadingService,
         persistence: PersistenceStore) {
        self.wallpaper = wallpaper
        self.videoWallpaper = videoWallpaper
        self.imageLoader = imageLoader
        self.persistence = persistence
    }

    func loadFullImage() async throws -> UIImage {
        if let vw = videoWallpaper, let url = vw.image {
            return try await imageLoader.load(url: url)
        }
        guard let url = wallpaper?.src.large else {
            throw NSError(domain: "Tessera", code: -1, userInfo: [NSLocalizedDescriptionKey: "No image URL"])
        }
        return try await imageLoader.load(url: url)
    }

    func toggleFavorite() {
        let id = videoWallpaper?.id.description ?? wallpaper?.id ?? ""
        persistence.toggleFavorite(id)
    }

    func favoriteID() -> String {
        videoWallpaper?.id.description ?? wallpaper?.id ?? ""
    }
}
