import SwiftUI

// MARK: - Root app
@main
struct TesseraApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.colorScheme) private var systemColorScheme

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.onboardingCompleted {
                    RootView()
                        .environmentObject(appState)
                        .onOpenURL { url in
                            appState.handleDeepLink(url)
                        }
                } else {
                    OnboardingView {
                        appState.onboardingCompleted = true
                        appState.persistence.onboardingCompleted = true
                    }
                    .environmentObject(appState)
                }
            }
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
                .accessibilityLabel("Explore tab")

            VideoDiscoverView(viewModel: appState.videoDiscoverVM)
                .tabItem {
                    Label("Videos", systemImage: "film")
                }
                .accessibilityLabel("Videos tab")

            FavoritesView(viewModel: appState.favoritesVM)
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
                .accessibilityLabel("Favorites tab")

            CollectionsView(viewModel: appState.collectionsVM)
                .tabItem {
                    Label("Featured", systemImage: "star.fill")
                }
                .accessibilityLabel("Featured tab")

            SettingsView(viewModel: appState.settingsVM)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .accessibilityLabel("Settings tab")
        }
        .tint(.accentColor)
    }
}

// MARK: - Root view preview
#Preview {
    let appState = AppState()
    return RootView()
        .environmentObject(appState)
}

// MARK: - App state (DI container)
@MainActor
final class AppState: ObservableObject {
    let network: WallpaperNetworkService
    let imageLoader: ImageLoadingService
    let persistence: PersistenceStore
    let filterCache: FilterImageCache
    let detailCoordinator: WallpaperDetailCoordinator

    let discoverVM: DiscoverViewModel
    let videoDiscoverVM: VideoDiscoverViewModel
    let favoritesVM: FavoritesViewModel
    let collectionsVM: CollectionsViewModel
    let telegramSync: TelegramSyncService

    let settingsVM: SettingsViewModel

    let videoNetwork: WallpaperVideoNetworkService
    let livePhotoConverter: LivePhotoConverter
    #if POSTERBOARD
    let posterApplyService: PosterBoardApplyService
    #endif

    @Published var onboardingCompleted: Bool

    init() {
        filterCache = FilterImageCache()
        persistence = UserDefaultsPersistenceStore()
        detailCoordinator = WallpaperDetailCoordinator()

        onboardingCompleted = persistence.onboardingCompleted

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--mock-network") {
            network = MockNetworkService()
        } else if ProcessInfo.processInfo.arguments.contains("--telegram-sync") {
            network = TelegramSyncService(baseURL: "http://localhost:8787")
        } else {
            network = PexelsNetworkService()
        }
        #else
        network = PexelsNetworkService()
        #endif

        telegramSync = TelegramSyncService()

        imageLoader = KingfisherImageLoader()
        videoNetwork = PexelsVideoService()
        livePhotoConverter = LivePhotoConverter()
        #if POSTERBOARD
        posterApplyService = PosterBoardApplyService()
        #endif

        discoverVM = DiscoverViewModel(network: network, imageLoader: imageLoader, persistence: persistence, coordinator: detailCoordinator, telegram: telegramSync)
        videoDiscoverVM = VideoDiscoverViewModel(videoNetwork: videoNetwork, imageLoader: imageLoader, persistence: persistence, coordinator: detailCoordinator)
        favoritesVM = FavoritesViewModel(persistence: persistence, imageLoader: imageLoader, network: network)
        collectionsVM = CollectionsViewModel(network: network, persistence: persistence)
        settingsVM = SettingsViewModel(persistence: persistence, cache: filterCache)

        // Wire coordinator to the top-most UIViewController
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            detailCoordinator.rootViewController = root.topMostViewController()
        }
    }

    var effectiveColorScheme: ColorScheme {
        preferredColorScheme ?? (UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light)
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
        // tessera://wallpaper/<id>
        guard url.scheme == "tessera",
              url.host == "wallpaper",
              let id = url.pathComponents.last else {
            return
        }

        // Find the wallpaper in current data
        let wallpapers = discoverVM.wallpapers + favoritesVM.favorites
        if let match = wallpapers.first(where: { $0.id == id || "\($0.id)" == id }) {
            detailCoordinator.showDetail(for: match)
        }
    }
}

// MARK: - UIViewController helpers for deep linking
extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMostViewController()
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostViewController()
        }
        return self
    }
}

// MARK: - Color extensions
extension Color {
    static let accentColor = Color(red: 0.878, green: 0.125, blue: 0.125)
}

// MARK: - UIImage scale helper
extension UIScreen {
    static var mainScreenScale: CGFloat {
        #if targetEnvironment(simulator)
        return 2.0
        #else
        return UIScreen.main.scale
        #endif
    }
}
