import UIKit

// MARK: - Detail model
@MainActor
final class WallpaperDetailModel: ObservableObject {
    let wallpaper: Wallpaper
    private let imageLoader: ImageLoadingService
    private let persistence: PersistenceStore

    // Sync accessors backed by the sync PersistenceStore properties
    var blurMode: BlurMode {
        get { persistence.blurMode }
        set { persistence.blurMode = newValue }
    }

    var isFavorited: Bool { persistence.hasFavorited(wallpaper.id) }

    // Convenience init used by coordinators / views
    convenience init(wallpaper: Wallpaper,
                     persistence: PersistenceStore = UserDefaultsPersistenceStore()) {
        let loader = KingfisherImageLoader()
        self.init(wallpaper: wallpaper, imageLoader: loader, persistence: persistence)
    }

    // Full init for testability
    init(wallpaper: Wallpaper,
         imageLoader: ImageLoadingService,
         persistence: PersistenceStore) {
        self.wallpaper = wallpaper
        self.imageLoader = imageLoader
        self.persistence = persistence
    }

    func loadFullImage() async throws -> UIImage {
        try await imageLoader.load(url: wallpaper.src.large)
    }

    func toggleFavorite() {
        persistence.toggleFavorite(wallpaper.id)
    }
}
