import Foundation
import UIKit
import CoreImage

// MARK: - UserDefaults-backed persistence
final class UserDefaultsPersistenceStore: PersistenceStore {
    private let defaults: UserDefaults
    private let favoritesKey = "tessera_favorites"
    private let themeKey = "tessera_theme"
    private let blurKey = "tessera_blur_mode"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var favorites: Set<String> {
        get async {
            guard let raw = defaults.stringArray(forKey: favoritesKey) else { return [] }
            return Set(raw)
        }
        set async {
            defaults.set(Array(newValue), forKey: favoritesKey)
        }
    }

    func hasFavorited(_ id: String) -> Bool {
        (defaults.stringArray(forKey: favoritesKey) ?? []).contains(id)
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

    var selectedTheme: AppTheme {
        get async {
            guard let raw = defaults.string(forKey: themeKey),
                  let theme = AppTheme(rawValue: raw) else {
                return .system
            }
            return theme
        }
        set async {
            defaults.set(newValue.rawValue, forKey: themeKey)
        }
    }

    var blurMode: BlurMode {
        get async {
            guard let raw = defaults.string(forKey: blurKey),
                  let mode = BlurMode(rawValue: raw) else {
                return .gaussian
            }
            return mode
        }
        set async {
            defaults.set(newValue.rawValue, forKey: blurKey)
        }
    }
}
