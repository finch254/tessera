import Foundation
import UIKit

// MARK: - Errors
enum PosterApplyError: Error, LocalizedError {
    case missingHash
    case symlinkFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingHash:
            return "No PosterBoard app hash set. Enter it in Settings → PosterBoard."
        case .symlinkFailed(let m):
            return "Could not link to PosterBoard's data store: \(m). This build must be sideloaded with filesystem access."
        }
    }
}

// MARK: - PosterBoard apply service
/// Applies a video wallpaper by writing its descriptor into PosterBoard's
/// sandbox through the .Trash symlink, then opening PosterBoard to refresh.
/// Sideloaded builds only (iOS 16+).
@MainActor
final class PosterBoardApplyService: ObservableObject {

    static let shared = PosterBoardApplyService()

    private let hashKey = "tessera.posterboard.appHash"

    @Published var appHash: String {
        didSet { UserDefaults.standard.set(appHash, forKey: hashKey) }
    }
    @Published var isApplying = false
    @Published var statusMessage: String?

    init() {
        appHash = UserDefaults.standard.string(forKey: hashKey) ?? ""
    }

    var hasHash: Bool {
        !appHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Apply the video at `videoURL` as a live lock-screen wallpaper.
    func applyVideoWallpaper(videoURL: URL,
                             autoReverses: Bool = false,
                             progress: ((Int, Int) -> Void)? = nil) async throws {
        let hash = appHash.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hash.isEmpty else { throw PosterApplyError.missingHash }

        isApplying = true
        defer {
            isApplying = false
            SymHandler.cleanup()
        }

        statusMessage = "Generating wallpaper frames…"

        // Build the descriptor off the main thread.
        let descrURL = try await Task.detached(priority: .userInitiated) {
            try PosterDescriptorBuilder.buildVideoDescriptor(
                from: videoURL,
                autoReverses: autoReverses,
                progress: progress
            )
        }.value

        statusMessage = "Linking to PosterBoard…"

        // Randomize the wallpaper id so PosterBoard treats it as new.
        randomizeWallpaperId(url: descrURL)

        // Point .Trash at PosterBoard's CollectionsPoster descriptors folder.
        do {
            try SymHandler.createDescriptorsSymlink(
                appHash: hash,
                ext: "com.apple.WallpaperKit.CollectionsPoster"
            )
        } catch {
            throw PosterApplyError.symlinkFailed(error.localizedDescription)
        }

        statusMessage = "Installing wallpaper…"

        // Move the descriptor into the trash — lands inside PosterBoard.
        let trashTarget = SymHandler.getDocumentsDirectory()
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.moveItem(at: descrURL, to: trashTarget)
        try FileManager.default.trashItem(at: trashTarget, resultingItemURL: nil)

        SymHandler.cleanup()
        statusMessage = "Opening PosterBoard…"

        // Open PosterBoard so it picks up the new descriptor.
        openPosterBoard()
        statusMessage = nil
    }

    // MARK: - Wallpaper id randomization
    private func randomizeWallpaperId(url: URL) {
        let randomizedID = Int.random(in: 9999...99999)
        var files = [URL]()
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                   values.isRegularFile == true {
                    files.append(fileURL)
                }
            }
        }

        for file in files {
            switch file.lastPathComponent {
            case "com.apple.posterkit.provider.descriptor.identifier":
                try? String(randomizedID).data(using: .utf8)?.write(to: file)
            case "com.apple.posterkit.provider.contents.userInfo":
                setPlistValue(file: file, key: "wallpaperRepresentingIdentifier", value: randomizedID)
            case "Wallpaper.plist":
                setPlistValue(file: file, key: "identifier", value: randomizedID)
            default:
                continue
            }
        }
    }

    private func setPlistValue(file: URL, key: String, value: Any) {
        guard let plistData = FileManager.default.contents(atPath: file.path),
              var plist = try? PropertyListSerialization.propertyList(
                  from: plistData, options: [], format: nil) as? [String: Any] else {
            return
        }
        plist[key] = value
        guard let updated = try? PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0) else {
            return
        }
        try? updated.write(to: file)
    }

    // MARK: - Open PosterBoard
    @discardableResult
    private func openPosterBoard() -> Bool {
        guard let obj = objc_getClass("LSApplicationWorkspace") as? NSObject else { return false }
        let workspace = obj.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() as? NSObject
        if let success = workspace?.perform(Selector(("openApplicationWithBundleID:")),
                                            with: "com.apple.PosterBoard") {
            return success != nil
        }
        return false
    }
}
