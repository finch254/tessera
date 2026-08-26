import Foundation
import UIKit

// MARK: - Wallpaper model
struct Wallpaper: Identifiable, Hashable, Sendable {
    let id: String
    let photographer: String
    let photographerId: String
    let width: Int
    let height: Int
    let avgColor: String?
    let src: PexelsImageURLs
    let alt: String?
    let liked: Bool?

    var title: String { photographer }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Wallpaper, rhs: Wallpaper) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - URL helpers
struct PexelsImageURLs: Sendable {
    let raw: URL
    let large2x: URL?
    let large: URL
    let medium: URL
    let small: URL
    let portrait: URL?
    let landscape: URL?
    let tiny: URL

    init(from dict: [String: Any]) {
        raw = URL(string: dict["raw"] as? String ?? "") ?? URL(string: "https://example.com")!
        large2x = URL(string: dict["large2x"] as? String ?? "")
        large = URL(string: dict["large"] as? String ?? "") ?? URL(string: "https://example.com")!
        medium = URL(string: dict["medium"] as? String ?? "") ?? URL(string: "https://example.com")!
        small = URL(string: dict["small"] as? String ?? "") ?? URL(string: "https://example.com")!
        portrait = URL(string: dict["portrait"] as? String ?? "")
        landscape = URL(string: dict["landscape"] as? String ?? "")
        tiny = URL(string: dict["tiny"] as? String ?? "") ?? URL(string: "https://example.com")!
    }
}

// MARK: - Category
struct WallpaperCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let slug: String
    let imageUrl: URL?
}

// MARK: - Filter definition
struct WallpaperFilter: Identifiable, Sendable {
    let id: String
    let name: String
    let iconName: String
    let apply: @Sendable (CIImage) -> CIImage
}

// MARK: - Palette color
struct PaletteColor: Sendable {
    let color: UIColor
    let population: Int
}
