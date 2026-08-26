import SwiftUI
import Combine

// MARK: - Discover view model
@MainActor
final class DiscoverViewModel: ObservableObject {
    let network: WallpaperNetworkService
    let imageLoader: ImageLoadingService
    let persistence: PersistenceStore

    @Published var wallpapers: [Wallpaper] = []
    @Published var categories: [WallpaperCategory] = []
    @Published var selectedCategory: WallpaperCategory?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedWallpaper: Wallpaper?
    @Published var searchResults: [Wallpaper] = []

    private var currentPage = 1
    private var hasNext = true
    private var searchQuery: String?
    private var isSearching = false

    init(network: WallpaperNetworkService,
         imageLoader: ImageLoadingService,
         persistence: PersistenceStore) {
        self.network = network
        self.imageLoader = imageLoader
        self.persistence = persistence
        Task { await loadCategories() }
        Task { await refresh() }
    }

    // MARK: - Categories
    func loadCategories() async {
        // Static curated categories with fallback image URLs from Pexels
        let defaultCategories: [WallpaperCategory] = [
            .init(id: "nature", name: "Nature", slug: "nature",
                  imageUrl: URL(string: "https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg")),
            .init(id: "city", name: "Cities", slug: "city",
                  imageUrl: URL(string: "https://images.pexels.com/photos/1105731/pexels-photo-1105731.jpeg")),
            .init(id: "abstract", name: "Abstract", slug: "abstract",
                  imageUrl: URL(string: "https://images.pexels.com/photos/2089846/pexels-photo-2089846.jpeg")),
            .init(id: "technology", name: "Tech", slug: "technology",
                  imageUrl: URL(string: "https://images.pexels.com/photos/3159679/pexels-photo-3159679.jpeg")),
            .init(id: "space", name: "Space", slug: "space",
                  imageUrl: URL(string: "https://images.pexels.com/photos/1040480/pexels-photo-1040480.jpeg")),
            .init(id: "minimal", name: "Minimal", slug: "minimal",
                  imageUrl: URL(string: "https://images.pexels.com/photos/3124944/pexels-photo-3124944.jpeg")),
            .init(id: "animals", name: "Animals", slug: "animals",
                  imageUrl: URL(string: "https://images.pexels.com/photos/4520165/pexels-photo-4520165.jpeg")),
            .init(id: "textures", name: "Textures", slug: "textures",
                  imageUrl: URL(string: "https://images.pexels.com/photos/5318361/pexels-photo-5318361.jpeg")),
        ]
        categories = defaultCategories
    }

    // MARK: - Browse
    func refresh() async {
        currentPage = 1
        hasNext = true
        searchQuery = nil
        await fetchPage(reset: true)
    }

    func loadNextPage() async {
        guard hasNext, !isLoading else { return }
        currentPage += 1
        await fetchPage(reset: false)
    }

    func selectCategory(_ category: WallpaperCategory) async {
        selectedCategory = category
        searchQuery = category.slug
        currentPage = 1
        hasNext = true
        await fetchPage(reset: true)
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        isSearching = true
        searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        currentPage = 1
        hasNext = true
        do {
            let response = try await network.fetchSearch(query: searchQuery, page: 1, perPage: 40)
            searchResults = response.results
            hasNext = response.hasNext
        } catch {
            self.error = error
        }
        isSearching = false
    }

    func reset() async {
        searchResults = []
        searchQuery = nil
        currentPage = 1
        await refresh()
    }

    private func fetchPage(reset: Bool) async {
        isLoading = true
        do {
            let response: PaginatedResponse<Wallpaper>
            if let cat = selectedCategory {
                response = try await network.fetchCategory(slug: cat.slug, page: currentPage, perPage: 40)
            } else {
                response = try await network.fetchPopular(page: currentPage, perPage: 40)
            }

            if reset {
                wallpapers = response.results
            } else {
                wallpapers.append(contentsOf: response.results)
            }
            hasNext = response.hasNext
            currentPage = response.page
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
