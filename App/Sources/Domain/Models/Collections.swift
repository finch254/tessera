import Foundation
import UIKit

// MARK: - Collection / Featured Pack
struct WallpaperCollection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let coverImageURL: URL
    let wallpaperIDs: [String]
    let isPremium: Bool
    let authorName: String?
}

// MARK: - Daily wallpaper record
struct DailyWallpaper: Identifiable, Hashable, Sendable {
    let id: String
    let date: Date
    let wallpaper: Wallpaper
}

// MARK: - App themes
enum AppTheme: String, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    case amoled = "AMOLED"
}

// MARK: - Blur modes
enum BlurMode: String, CaseIterable, Sendable {
    case off = "Off"
    case light = "Light"
    case dark = "Dark"
    case vibrant = "Vibrant"
    case tinted = "Tinted"
}

// MARK: - Download quality
enum DownloadQuality: String, CaseIterable, Sendable {
    case original = "Original"
    case large2x = "Large 2x"
    case large = "Large"
    case medium = "Medium"
}
