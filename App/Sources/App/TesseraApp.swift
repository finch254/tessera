import SwiftUI

// MARK: - Root app
@main
struct TesseraApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environment(\.colorScheme, appState.effectiveColorScheme)
                .preferredColorScheme(appState.preferredColorScheme)
        }
    }
}

// MARK: - Root view (tab bar)
struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            DiscoverView(viewModel: appState.discoverVM)
                .tabItem {
                    Label("Explore", systemImage: "photo.on.rectangle.angled")
                }

            FavoritesView(viewModel: appState.favoritesVM)
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }

            SettingsView(viewModel: appState.settingsVM)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.accentColor)
        .onOpenURL { url in
            appState.handleDeepLink(url)
        }
    }
}

// MARK: - App state (DI container)
@MainActor
final class AppState: ObservableObject {
    let network: WallpaperNetworkService
    let imageLoader: ImageLoadingService
    let persistence: PersistenceStore
    let filterCache: FilterImageCache

    let discoverVM: DiscoverViewModel
    let favoritesVM: FavoritesViewModel
    let settingsVM: SettingsViewModel

    init() {
        filterCache = FilterImageCache()
        persistence = UserDefaultsPersistenceStore()

        #if DEBUG
        // In debug, use a mock network to test without API key
        if ProcessInfo.processInfo.arguments.contains("--mock-network") {
            network = MockNetworkService()
        } else {
            network = PexelsNetworkService()
        }
        #else
        network = PexelsNetworkService()
        #endif

        imageLoader = KingfisherImageLoader()

        discoverVM = DiscoverViewModel(network: network, imageLoader: imageLoader, persistence: persistence)
        favoritesVM = FavoritesViewModel(persistence: persistence, imageLoader: imageLoader, network: network)
        settingsVM = SettingsViewModel(persistence: persistence, cache: filterCache)
    }

    var effectiveColorScheme: ColorScheme {
        appState.preferredColorScheme ?? systemColorScheme
    }

    var preferredColorScheme: ColorScheme? {
        switch persistence.selectedTheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        case .amoled: return .dark
        }
    }

    func handleDeepLink(_ url: URL) {
        // Parse deep links like "tessera://wallpaper/<id>"
        guard url.scheme == "tessera",
              url.host == "wallpaper",
              let id = url.pathComponents.last else {
            return
        }
        // Navigate to detail — would need a coordinator; for now just log
        print("Deep link: show wallpaper \(id)")
    }
}

// MARK: - Color extensions
extension Color {
    static let accentColor = Color(red: 0.9, green: 0.2, blue: 0.2) // red-ish, matches doors' brand
}

// MARK: - UIImage scale helper
extension UIScreen {
    var mainScreenScale: CGFloat {
        #if targetEnvironment(simulator)
        return 2.0 // simulator default
        #else
        return UIScreen.main.scale
        #endif
    }
}
