# Contributing to Tessera

Thanks for your interest in improving Tessera. All contributions are welcome.

## Development setup

1. Clone the repo and open `Tessera.xcodeproj` in Xcode 16+.
2. Run `xcodebuild -resolvePackageDependencies` to fetch Kingfisher + SnapKit.
3. Set `PEXELS_API_KEY` in your scheme (Edit Scheme > Run > Arguments > Environment Variables).
4. Build and run on a simulator or device (iOS 16.0+).

## Code style

- Use Swift 5.9, SwiftUI for new screens, UIKit only when CoreImage or fine-grained layout is required.
- Follow the Swift API Design Guidelines.
- Keep files focused: one screen / one view model / one service per file.
- Use `private` and `fileprivate` — avoid `internal` leakage.
- Run `swiftformat .` and `swiftlint` (if installed) before committing.

## Testing

- Add unit tests under `Tests/TesseraTests/` for any non-UI logic.
- Mock dependencies via the existing protocol interfaces (`WallpaperNetworkService`, `ImageLoadingService`, `PersistenceStore`).
- Name tests descriptively: `testToggleCategoryFiltersWallpapers` not `test1`.

## Pull requests

- Keep PRs small and focused.
- Update `README.md` if you add a user-facing feature.
- Ensure the app still builds (CI runs on PRs).

## License

By contributing, you agree your code will be licensed under MIT, the same as Tessera.
