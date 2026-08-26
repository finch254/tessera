import SwiftUI

// MARK: - Coordinator for presenting detail VC from SwiftUI
@MainActor
final class WallpaperDetailCoordinator: ObservableObject {
    weak var rootViewController: UIViewController?
    let persistence: PersistenceStore
    let imageLoader: ImageLoadingService

    init(persistence: PersistenceStore = UserDefaultsPersistenceStore(),
         imageLoader: ImageLoadingService = KingfisherImageLoader()) {
        self.persistence = persistence
        self.imageLoader = imageLoader
    }

    func showDetail(for wallpaper: Wallpaper) {
        let model = WallpaperDetailModel(
            wallpaper: wallpaper,
            imageLoader: imageLoader,
            persistence: persistence
        )
        let vc = WallpaperDetailViewController.create(model: model)
        vc.modalPresentationStyle = .fullScreen
        rootViewController?.present(vc, animated: true)
    }
}
