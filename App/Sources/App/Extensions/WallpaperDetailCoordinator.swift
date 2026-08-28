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
        // Wrap in UINavigationController so nav bar / gestures work (fixes
        // the "tap does nothing" bug from the original wallpaper-ios port).
        rootViewController?.present(vc.embedInNavigationController(), animated: true)
    }

    func showVideoDetail(for video: VideoWallpaper) {
        let model = WallpaperDetailModel(videoWallpaper: video, imageLoader: imageLoader, persistence: persistence)
        let vc = WallpaperDetailViewController.create(model: model)
        vc.modalPresentationStyle = .fullScreen
        rootViewController?.present(vc.embedInNavigationController(), animated: true)
    }
}

// MARK: - UINavigationController helper
private extension UIViewController {
    func embedInNavigationController() -> UINavigationController {
        let nav = UINavigationController(rootViewController: self)
        nav.isNavigationBarHidden = false
        return nav
    }
}
