import Combine
import UIKit

// MARK: - Detail model (ViewModel for the detail screen)
@MainActor
final class WallpaperDetailModel: ObservableObject {
    let wallpaper: Wallpaper
    private let imageLoader: ImageLoadingService
    private let persistence: PersistenceStore
    private var cancellables = Set<AnyCancellable>()

    var blurMode: BlurMode {
        get async { await persistence.blurMode }
        set { persistence.blurMode = newValue }
    }

    var isFavorited: Bool { persistence.hasFavorited(wallpaper.id) }

    init(wallpaper: Wallpaper, imageLoader: ImageLoadingService, persistence: PersistenceStore) {
        self.wallpaper = wallpaper
        self.imageLoader = imageLoader
        self.persistence = persistence
    }

    func loadFullImage() async throws -> UIImage {
        // Use the large image URL
        try await imageLoader.load(url: wallpaper.src.large)
    }

    func toggleFavorite() {
        persistence.toggleFavorite(wallpaper.id)
    }
}
