import SwiftUI
import Combine
import ActivityKit

@MainActor
final class CollectionsViewModel: ObservableObject {
    @Published var collections: [WallpaperCollection] = []
    @Published var daily: DailyWallpaper?
    @Published var isLoading = false
    @Published var errorMessage: String?

    let network: WallpaperNetworkService
    let persistence: PersistenceStore

    private var dailyTask: Task<Void, Never>?
    private var dailyTimerCancellable: AnyCancellable?

    init(network: WallpaperNetworkService, persistence: PersistenceStore) {
        self.network = network
        self.persistence = persistence
        loadCollections()
        startDailyCheck()
    }

    deinit {
        dailyTimerCancellable?.cancel()
        dailyTask?.cancel()
    }

    // MARK: - Load collections
    func loadCollections() {
        isLoading = true
        errorMessage = nil

        // Curated featured packs — in production these would come from an API
        collections = [
            WallpaperCollection(
                id: "trending-now",
                title: "Trending Now",
                subtitle: "Most popular wallpapers this week",
                coverImageURL: URL(string: "https://images.pexels.com/photos/1287145/pexels-photo-1287145.jpeg")!,
                wallpaperIDs: [],
                isPremium: false,
                authorName: nil
            ),
            WallpaperCollection(
                id: "new-artists",
                title: "New Artists",
                subtitle: "Fresh picks from new photographers",
                coverImageURL: URL(string: "https://images.pexels.com/photos/1563356/pexels-photo-1563356.jpeg")!,
                wallpaperIDs: [],
                isPremium: false,
                authorName: nil
            ),
            WallpaperCollection(
                id: "oled-dark",
                title: "OLED Dark",
                subtitle: "True black wallpapers for AMOLED screens",
                coverImageURL: URL(string: "https://images.pexels.com/photos/1323550/pexels-photo-1323550.jpeg")!,
                wallpaperIDs: [],
                isPremium: false,
                authorName: nil
            ),
            WallpaperCollection(
                id: "minimal",
                title: "Minimalist",
                subtitle: "Clean, simple designs",
                coverImageURL: URL(string: "https://images.pexels.com/photos/1029116/pexels-photo-1029116.jpeg")!,
                wallpaperIDs: [],
                isPremium: false,
                authorName: nil
            ),
            WallpaperCollection(
                id: "nature-4k",
                title: "Nature 4K",
                subtitle: "Ultra high-res landscapes",
                coverImageURL: URL(string: "https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg")!,
                wallpaperIDs: [],
                isPremium: true,
                authorName: "Premium"
            ),
            WallpaperCollection(
                id: "abstract-art",
                title: "Abstract Art",
                subtitle: "Bold colors and shapes",
                coverImageURL: URL(string: "https://images.pexels.com/photos/1563356/pexels-photo-1563356.jpeg")!,
                wallpaperIDs: [],
                isPremium: false,
                authorName: nil
            ),
        ]

        // Load daily wallpaper
        loadDaily()
        isLoading = false
    }

    // MARK: - Daily wallpaper
    func loadDaily() {
        dailyTask?.cancel()

        // Check if we already have today's wallpaper
        let todayID = Calendar.current.startOfDay(for: Date())
        if let lastID = persistence.lastDailyWallpaperID,
           let lastDate = ISO8601DateFormatter().date(from: lastID),
           Calendar.current.isDate(lastDate, inSameDayAs: Date()) {
            // Already have today's — in a real app we'd cache it
            return
        }

        dailyTask = Task { [weak self] in
            do {
                let response = try await self?.network.fetchPopular(page: 1, perPage: 1)
                guard let wallpaper = response?.results.first else { return }
                let dailyRecord = DailyWallpaper(id: UUID().uuidString, date: Date(), wallpaper: wallpaper)
                await MainActor.run {
                    self?.daily = dailyRecord
                    self?.persistence.lastDailyWallpaperID = ISO8601DateFormatter().string(from: Date())
                }

                // Start Live Activity for daily wallpaper
                let started = await DailyWallpaperActivityManager.startActivity(wallpaper: wallpaper)
                if !started {
                    print("Live Activity not started — check Settings > Tessera > Live Activities")
                }
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startDailyCheck() {
        // Check for new daily wallpaper every hour
        dailyTimerCancellable = Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.loadDaily()
            }
    }

    // MARK: - Actions
    func refresh() {
        loadCollections()
    }

    func setWallpaper(_ wallpaper: Wallpaper, quality: DownloadQuality = .medium) async {
        // Download and set as wallpaper — implemented in detail screen
        // This is a placeholder that triggers the system wallpaper picker
        await MainActor.run {
            // Will be handled by presenting the detail coordinator
        }
    }
}
