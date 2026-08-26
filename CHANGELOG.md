# Changelog

All notable changes to Tessera will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-26

### Added
- Initial open-source release of Tessera
- Native SwiftUI + UIKit/CoreImage architecture
- 25 Swift source files across Features, Domain, and Infrastructure
- Masonry browse with 2-column adaptive grid
- 18 camera-style filters (Clarendon, Hudson, Mayfair, etc.)
- Real-time blur preview with off / light / dark / vibrant / tinted modes
- Icon overlay preview using SF Symbols springboard mock
- k-means dominant color palette extraction
- Favorites with local persistence
- 4 themes: System, Light, Dark, AMOLED
- Pexels API integration with mock network fallback
- Deep linking: `tessera://wallpaper/<id>`
- ActivityKit Live Activity for daily wallpaper (Lock Screen + Dynamic Island)
- Dynamic Island device availability check
- Featured collections with curated wallpaper packs
- Daily wallpaper banner with hourly refresh
- Telegram channel sync via Cloudflare Worker backend
- Settings toggle for Telegram sync
- Unit test stubs for DiscoverViewModel, FilterEngine, PaletteExtractor
- SwiftUI preview for DiscoverView
- MIT license

### Fixed
- Cross-file protocol/impl mismatches in PersistenceStore
- Duplicate enum definitions (AppTheme, BlurMode)
- Unused imports and dead code removal
- README architecture tree accuracy

## [Unreleased]

### Planned
- WidgetKit home-screen widget for daily wallpaper
- Share/export filtered wallpaper with icon overlay
- Onboarding flow for first launch
- Full accessibility labels and VoiceOver support
- SwiftUI previews for Favorites, Collections, Settings
- GitHub Actions CI workflow
- Real app icon variants for all iOS sizes
- App Store submission
