import UIKit
import SwiftUI

// MARK: - Share / export service
final class ShareExportService {
    static let shared = ShareExportService()

    private init() {}

    func shareImage(_ image: UIImage, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        viewController.present(activityVC, animated: true)
    }

    func shareImage(_ image: UIImage, sourceView: UIView) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let presenter = sourceView.window?.rootViewController {
            presenter.present(activityVC, animated: true)
        }
    }
}
