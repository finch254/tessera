import SwiftUI

// MARK: - Favorites tab
struct FavoritesView: View {
    @ObservedObject var viewModel: FavoritesViewModel

    @State private var selectedWallpaper: Wallpaper?
    @State private var coordinator = WallpaperDetailCoordinator()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.favorites.isEmpty {
                    emptyState
                } else {
                    masonryGrid
                }
            }
            .navigationTitle("Favorites")
            .sheet(item: $selectedWallpaper) { wallpaper in
                DetailHost(wallpaper: wallpaper, coordinator: coordinator)
            }
            .task {
                await viewModel.loadFavorites()
            }

        }
    }

    // MARK: - Empty state
    private var emptyState: some View {
        ContentUnavailableView(
            "No Favorites Yet",
            systemImage: "heart.slash",
            description: Text("Tap the heart on any wallpaper to save it here.")
        )
    }

    // MARK: - Masonry grid
    private var masonryGrid: some View {
        ScrollView {
            LazyVGrid(columns: masonryColumns, spacing: 2) {
                ForEach(viewModel.favorites) { wallpaper in
                    favoriteCell(wallpaper: wallpaper)
                        .onTapGesture {
                            selectedWallpaper = wallpaper
                        }
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 80)
        }
        .overlay {
            if viewModel.favorites.isEmpty {
                emptyState
            }
        }
    }

    @ViewBuilder
    private func favoriteCell(wallpaper: Wallpaper) -> some View {
        let width: CGFloat = 180
        let aspectRatio = (wallpaper.height as CGFloat) / max(wallpaper.width as CGFloat, 1)
        let height = width / max(aspectRatio, 0.5)

        ZStack(alignment: .bottom) {
            if let url = wallpaper.src.medium {
                KFImage(url)
                    .placeholder { Color.gray.opacity(0.3) }
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: width, height: height)
            }

            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: height)

            HStack {
                Text(wallpaper.photographer)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.caption.weight(.bold))
            }
            .padding(8)
            .background(Color.black.opacity(0.4).clipShape(RoundedRectangle(cornerRadius: 6)))
        }
        .aspectRatio(16/9, contentComparison: .priority)
    }

    private var masonryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 2)
    }
}

// MARK: - Favorites view model
@MainActor
final class FavoritesViewModel: ObservableObject {
    let persistence: PersistenceStore
    let imageLoader: ImageLoadingService
    let network: WallpaperNetworkService

    @Published var favorites: [Wallpaper] = []


    init(persistence: PersistenceStore,
         imageLoader: ImageLoadingService,
         network: WallpaperNetworkService) {
        self.persistence = persistence
        self.imageLoader = imageLoader
        self.network = network
    }

    func loadFavorites() async {
        let favoriteIDs = await persistence.favorites
        guard !favoriteIDs.isEmpty else {
            favorites = []
            return
        }

        var results: [Wallpaper] = []
        var page = 1
        repeat {
            do {
                let response = try await network.fetchPopular(page: page, perPage: 40)
                for w in response.results where favoriteIDs.contains(w.id) {
                    results.append(w)
                }
                if response.results.count < 40 { break }
                page += 1
            } catch {
                break
            }
        } while results.count < favoriteIDs.count

        favorites = results
    }

}
