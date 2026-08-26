import SwiftUI

// MARK: - Favorites tab
struct FavoritesView: View {
    @ObservedObject var viewModel: FavoritesViewModel

    var body: some View {
        NavigationStack {
            if viewModel.favorites.isEmpty {
                emptyState
            } else {
                masonryGrid
            }
        }
        .navigationTitle("Favorites")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Favorites Yet",
            systemImage: "heart.slash",
            description: Text("Tap the heart on any wallpaper to save it here.")
        )
    }

    private var masonryGrid: some View {
        ScrollView {
            LazyVGrid(columns: masonryColumns, spacing: 2) {
                ForEach(viewModel.favorites) { wallpaper in
                    FavoriteWallpaperCell(wallpaper: wallpaper)
                        .onTapGesture {
                            viewModel.selectedWallpaper = wallpaper
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

    private var masonryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 2)
    }
}

// MARK: - Favorite cell
struct FavoriteWallpaperCell: View {
    let wallpaper: Wallpaper

    var body: some View {
        ZStack(alignment: .bottom) {
            KFImage(wallpaper.src.medium)
                .placeholder { Color.gray.opacity(0.3) }
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipped()

            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)

            HStack {
                Text(wallpaper.photographer)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "heart.fill")
                    .foregroundColor(.systemRed)
                    .font(.caption.weight(.bold))
            }
            .padding(8)
            .background(Color.black.opacity(0.4).clipShape(RoundedRectangle(cornerRadius: 6)))
        }
        .aspectRatio(16/9, contentComparison: .priority)
    }
}

// MARK: - Favorites view model
@MainActor
final class FavoritesViewModel: ObservableObject {
    let persistence: PersistenceStore
    let imageLoader: ImageLoadingService
    let network: WallpaperNetworkService

    @Published var favorites: [Wallpaper] = []
    @Published var selectedWallpaper: Wallpaper?

    init(persistence: PersistenceStore,
         imageLoader: ImageLoadingService,
         network: WallpaperNetworkService) {
        self.persistence = persistence
        self.imageLoader = imageLoader
        self.network = network
        Task { await loadFavorites() }
    }

    func loadFavorites() async {
        let favoriteIDs = await persistence.favorites
        guard !favoriteIDs.isEmpty else {
            favorites = []
            return
        }

        // Fetch the actual wallpaper data from network
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
