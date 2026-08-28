import Foundation

// MARK: - SymHandler
/// Creates the filesystem symlink that lets a sideloaded app write wallpaper
/// descriptors directly into PosterBoard's sandbox. Technique from Pocket
/// Poster / Nugget / Cowabunga: the app's Documents/.Trash is symlinked to the
/// target app's hashed container, then descriptor folders are moved to trash,
/// which lands them inside PosterBoard's extension data store.
///
/// Only works when the app is sideloaded with raw filesystem access (iOS 16+).
enum SymHandler {

    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Some sideload toolchains expose an alternate home via LC_HOME_PATH.
    static func getLCDocumentsDirectory() -> URL {
        if let lcPath = ProcessInfo.processInfo.environment["LC_HOME_PATH"] {
            return URL(fileURLWithPath: "\(lcPath)/Documents")
        }
        return getDocumentsDirectory()
    }

    static func getPosterBoardHashURL() -> URL {
        getLCDocumentsDirectory().appendingPathComponent("NuggetPosterBoardHash")
    }

    private static func getSymlinkURL() -> URL {
        getLCDocumentsDirectory().appendingPathComponent(".Trash", conformingTo: .symbolicLink)
    }

    /// PosterBoard's extension data store version directory.
    static func getExtensionVersion() -> String {
        if #available(iOS 17.0, *) {
            return "61"
        }
        return "59"
    }

    @discardableResult
    static func createSymlink(to path: String) throws -> URL {
        let symURL = getSymlinkURL()
        cleanup()
        try FileManager.default.createSymbolicLink(
            at: symURL,
            withDestinationURL: URL(fileURLWithPath: path, isDirectory: true)
        )
        return symURL
    }

    @discardableResult
    static func createAppSymlink(for appHash: String) throws -> URL {
        try createSymlink(to: "/var/mobile/Containers/Data/Application/\(appHash)")
    }

    /// Symlink straight to a PosterBoard extension's descriptors folder.
    @discardableResult
    static func createDescriptorsSymlink(appHash: String, ext: String) throws -> URL {
        let extVer = getExtensionVersion()
        return try createAppSymlink(
            for: "\(appHash)/Library/Application Support/PRBPosterExtensionDataStore/\(extVer)/Extensions/\(ext)/descriptors"
        )
    }

    static func cleanup() {
        let symURL = getSymlinkURL()
        try? FileManager.default.removeItem(at: symURL)
    }
}
