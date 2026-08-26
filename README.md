# Tessera

A native iOS wallpaper discovery app with curated collections, daily wallpapers, and Live Activities on the Lock Screen and Dynamic Island. Browse thousands of high-quality photos, apply filters, preview with your app icons, and save favorites — all offline-capable after first load.

Built in Swift + SwiftUI + UIKit/CoreImage. Combines the best UX from three open-source wallpaper apps into one focused, App Store-ready experience.

## About

Tessera is built for iOS 16 and later. It adapts to every screen size from iPhone SE to Pro Max, supports Dynamic Island on iPhone 14 Pro and newer, and falls back gracefully on older devices.

The app is privacy-first: no analytics, no auth, no cloud sync, and no ads. Favorites, themes, blur modes, and wallpaper preferences are stored locally in UserDefaults.

## What's inside

| Feature | Detail |
|---------|--------|
| Masonry browse | 2-column adaptive grid, category chips, pull-to-refresh |
| Featured collections | Curated wallpaper packs with cover images and premium badges |
| Daily wallpaper | Fresh wallpaper every day with Live Activity on Lock Screen |
| Categories | Nature, Cities, Abstract, Tech, Space, Minimal, Animals, Textures |
| Search | Keyword search across wallpapers |
| Filters | 18 camera-style filters (Clarendon, Hudson, Mayfair, etc.) |
| Blur preview | Real-time blur slider with off / light / dark / vibrant / tinted modes |
| Icon overlay | See wallpaper with iPhone springboard icons before saving |
| Palette | Dominant colors extracted from any wallpaper (k-means) |
| Favorites | Save wallpapers locally, view in dedicated tab |
| Themes | System / Light / Dark / AMOLED |
| Dynamic Island | Live Activity with compact / minimal / expanded layouts (iOS 16.2+) |
| Live Activities | Lock Screen widget for daily wallpaper and in-progress actions |
| Pexels API | Free, high-quality photos via Pexels (sign up for a free key) |
| Offline fallback | Mock network mode for development without an API key |

## Screenshots (concept)

1. **Explore** — masonry grid with category chips at top, photographer attribution on each cell.
2. **Featured** — daily wallpaper banner + curated collection cards with premium badges.
3. **Detail** — full-screen wallpaper, tap to hide controls. Blur slider + filter strip + icon overlay toggle (springboard mock with SF Symbols).
4. **Favorites** — saved wallpapers grid with heart indicator.
5. **Settings** — theme picker, blur mode, clear cache, about + license attribution.

## Getting started

### 1. Clone

```bash
git clone https://github.com/finch254/tessera.git
cd tessera
```

### 2. Open in Xcode

Open `Tessera.xcodeproj` (or create one via File → New → Project → iOS App, name it "Tessera", and paste the `App/Sources/` folder into the project).

Target: **iOS 16.0+** (iOS 16.2+ for Live Activities / Dynamic Island).

### 3. Dependencies

Add these via **Swift Package Manager** (File → Add Package Dependencies):

- **Kingfisher** — image loading + caching (`https://github.com/onevcat/Kingfisher`)
- **SnapKit** — Auto Layout constraints (`https://github.com/SnapKit/SnapKit`)

### 4. Pexels API key

Sign up for a free API key at https://www.pexels.com/api/. Once you have it:

- In Xcode, go to your scheme → Edit Scheme → Run → Arguments → Environment Variables
- Add `PEXELS_API_KEY` = your key

Or add a `.env` file at the project root (excluded from Git via `.gitignore`) with:

```
PEXELS_API_KEY=your_key_here
```

The app falls back to `MockNetworkService` if the key isn't set (pass `--mock-network` to the scheme for pure offline development).

### 5. Build and run

Select a simulator or your device and hit Run. The app will load wallpapers from Pexels on first launch.

## Architecture

```
Tessera/
├── App/
│   └── TesseraApp.swift                          # @main entry, tab bar, DI container
├── Domain/
│   ├── Models/
│   │   ├── Wallpaper.swift                       # Data model, Pexels URL struct
│   │   ├── Collections.swift                     # Collection, DailyWallpaper, AppTheme, BlurMode
│   │   └── PaletteColor.swift                    # Dominant color + population
│   └── Protocols/
│       └── ServiceProtocols.swift                # Network + image loading + persistence protocols
├── Features/
│   ├── Discover/
│   │   ├── DiscoverView.swift                    # SwiftUI masonry grid + search
│   │   └── DiscoverViewModel.swift               # Category + page fetch logic
│   ├── Detail/
│   │   ├── WallpaperDetailModel.swift
│   │   └── WallpaperDetailViewController.swift   # UIKit: blur + icons + filters
│   ├── Favorites/
│   │   └── FavoritesView.swift
│   ├── Collections/
│   │   ├── CollectionsView.swift                 # Featured packs + daily wallpaper banner
│   │   └── CollectionsViewModel.swift
│   └── Settings/
│       └── SettingsView.swift                    # Theme, blur, cache, about
└── Infrastructure/
    ├── ColorExtraction/
    │   └── PaletteExtractor.swift                # k-means dominant color extraction
    ├── Database/
    │   └── UserDefaultsPersistenceStore.swift
    ├── Filtering/
    │   └── FilterEngine.swift                    # 18 CIFilter camera-style filters
    ├── ImageLoading/
    │   └── KingfisherImageLoader.swift
    ├── LiveActivity/
    │   ├── DailyWallpaperActivityManager.swift    # ActivityKit lifecycle
    │   └── DailyWallpaperActivityWidget.swift     # Lock Screen + Dynamic Island layouts
    └── Networking/
        ├── PexelsNetworkService.swift
        └── MockNetworkService.swift
```

## Design decisions

- **SwiftUI for screens, UIKit for detail** — the detail view needs CoreImage + fine-grained gesture control (blur slider, icon overlay toggle) that UIKit handles cleanly. `WallpaperDetailViewController` is hosted via `UIViewControllerRepresentable`.
- **No Firebase / no auth / no cloud** — privacy-first. Favorites, theme, and blur settings are stored in UserDefaults. No analytics, no crash reporting included (add your own if you want).
- **18 filters, not 100** — a curated set of camera-style filters that work well on wallpapers. Easy to add more by dropping a new `CIFilter` chain into `FilterEngine.makeFilters()`.
- **Pexels as primary source** — free tier is generous, no key required for basic usage (but recommended). Unsplash can be added as a secondary source by implementing `WallpaperNetworkService`.
- **Icon overlay** — uses SF Symbols to mock a springboard, so the preview works without device-specific home-screen photos. The real implementation from wallpaper-ios uses a pre-captured icons image; here we generate a placeholder from SF Symbols for demo purposes.
- **Dynamic Island awareness** — Live Activities and Dynamic Island layouts are implemented, but the Lock Screen is the primary surface. Devices without Dynamic Island still show the Lock Screen widget. Devices with Dynamic Island get compact, minimal, and expanded presentations.
- **Adaptive layout** — `LazyVGrid` with `.flexible()` columns and adaptive spacing handles every screen size from iPhone SE to Pro Max, including 1x / 2x / 3x DPI variants.

## Roadmap

- [ ] Real app icon variants for all iOS sizes (@1x / @2x / @3x)
- [ ] SwiftUI previews for all major views
- [ ] Universal Links (`tessera://wallpaper/<id>` deep link scaffolding is in place)
- [ ] WidgetKit home-screen widget for daily wallpaper
- [ ] Spatial / parallax wallpaper support (iOS 26+)
- [ ] On-device AI wallpaper suggestions (Core ML)
- [ ] Export/share filtered wallpaper with icon overlay
- [ ] App Store submission

## Credits

Wallpaper data from [Pexels](https://www.pexels.com/) under the Pexels License.  
Inspired by:

- [doors-wallpaper](https://github.com/kennethnym/doors-wallpaper) — clean masonry browse
- [wallpaper-ios](https://github.com/moridaffy/wallpaper-ios) — springboard icon overlay preview, blur slider
- [prism](https://github.com/Hash-Studios/prism) — camera filters, palette extraction, AMOLED themes

## License

MIT. See `LICENSE` file. Pexels content is subject to the [Pexels License](https://www.pexels.com/license/).

## Author

Dennis Finch — [finch254](https://github.com/finch254)
