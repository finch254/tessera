import Foundation
import UIKit

// MARK: - UserDefaults-backed persistence
final class UserDefaultsPersistenceStore: PersistenceStore {
    private let defaults: UserDefaults
    private let favoritesKey = "tessera_favorites"
    private let themeKey = "tessera_theme"
    private let blurKey = "tessera_blur_mode"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Favorites
    var favorites: Set<String> {
        get async {
            guard let raw = defaults.stringArray(forKey: favoritesKey) else { return [] }
            return Set(raw)
        }
    }

    var hasFavorited: (_ id: String) -> Bool {
        { id in
            (defaults.stringArray(forKey: self.favoritesKey) ?? []).contains(id)
        }
    }

    func toggleFavorite(_ id: String) {
        var current = defaults.stringArray(forKey: favoritesKey) ?? []
        if current.contains(id) {
            current.removeAll { $0 == id }
        } else {
            current.append(id)
        }
        defaults.set(current, forKey: favoritesKey)
    }

    // MARK: - Theme
    var selectedTheme: AppTheme {
        get {
            guard let raw = defaults.string(forKey: themeKey),
                  let theme = AppTheme(rawValue: raw) else {
                return .system
            }
            return theme
        }
        set {
            defaults.set(newValue.rawValue, forKey: themeKey)
        }
    }

    // MARK: - Auto-set
    var autoSetEnabled: Bool {
        get { defaults.bool(forKey: "tessera_auto_set") }
        set { defaults.set(newValue, forKey: "tessera_auto_set") }
    }

    var autoSetHour: Int {
        get { defaults.integer(forKey: "tessera_auto_set_hour") }
        set { defaults.set(newValue, forKey: "tessera_auto_set_hour") }
    }

    var lastDailyWallpaperID: String? {
        get { defaults.string(forKey: "tessera_last_daily_id") }
        set { defaults.setValue(newValue, forKey: "tessera_last_daily_id") }
    }

    // MARK: - Blur
    var blurMode: BlurMode {
        get {
            guard let raw = defaults.string(forKey: blurKey),
                  let mode = BlurMode(rawValue: raw) else {
                return .off
            }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: blurKey)
        }
    }
}
