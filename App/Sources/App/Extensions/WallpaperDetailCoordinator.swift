import SwiftUI

// MARK: - Coordinator for presenting detail VC from SwiftUI
@MainActor
final class WallpaperDetailCoordinator: ObservableObject {
    weak var rootViewController: UIViewController?

    func showDetail(for wallpaper: Wallpaper) {
        let model = WallpaperDetailModel(wallpaper: wallpaper)
        let vc = WallpaperDetailViewController.create(model: model)
        vc.modalPresentationStyle = .fullScreen
        rootViewController?.present(vc, animated: true)
    }
}
