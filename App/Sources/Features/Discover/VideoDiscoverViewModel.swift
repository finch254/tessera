import SwiftUI
import Combine

@MainActor
final class VideoDiscoverViewModel: ObservableObject {
    let videoNetwork: WallpaperVideoNetworkService
    let imageLoader: ImageLoadingService
    let persistence: PersistenceStore
    let coordinator: WallpaperDetailCoordinator

    @Published var videos: [VideoWallpaper] = []
    @Published var categories: [WallpaperCategory] = []
    @Published var selectedCategory: String?
    @Published var isLoading = false
    @Published var error: Error?

    @Published var searchText: String = ""
    @Published var searchResults: [VideoWallpaper] = []

    private var currentPage = 1
    private var hasNext = true
    private var searchQuery: String?
    private var currentTask: Task<Void, Never>?

    init(videoNetwork: WallpaperVideoNetworkService,
         imageLoader: ImageLoadingService,
         persistence: PersistenceStore,
         coordinator: WallpaperDetailCoordinator) {
        self.videoNetwork = videoNetwork
        self.imageLoader = imageLoader
        self.persistence = persistence
        self.coordinator = coordinator
        Task { await loadCategories() }
        Task { await resetAndFetch() }
    }

    var errorMessage: String? {
        error?.localizedDescription
    }

    var displayedVideos: [VideoWallpaper] {
        if searchText.isEmpty {
            return videos
        } else {
            return searchResults
        }
    }

    // MARK: - Categories
    func loadCategories() async {
        let videoCategories: [WallpaperCategory] = [
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
            .init(id: "animals", name: "Animals", slug: "animals",
                  imageUrl: URL(string: "https://images.pexels.com/photos/4520165/pexels-photo-4520165.jpeg")),
        ]
        categories = videoCategories
    }

    func selectCategory(_ id: String?) {
        selectedCategory = id
        searchQuery = nil
        searchText = ""
        searchResults = []
        currentPage = 1
        hasNext = true
        videos = []
        error = nil
        Task { await fetchPage() }
    }

    // MARK: - Browse
    func resetAndFetch() async {
        currentPage = 1
        hasNext = true
        searchQuery = nil
        searchResults = []
        videos = []
        error = nil
        await fetchPage()
    }

    func loadNextPage() async {
        guard hasNext, !isLoading else { return }
        currentPage += 1
        await fetchPage()
    }

    func loadNextPageIfNeeded() async {
        await loadNextPage()
    }

    func onItemAppeared(at index: Int) {
        let threshold = displayedVideos.count - 5
        if index >= threshold && hasNext && !isLoading {
            Task { await loadNextPage() }
        }
    }

    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedCategory = nil
        currentPage = 1
        hasNext = true
        videos = []
        await fetchPage()
    }

    private func fetchPage() async {
        guard currentTask == nil || currentTask?.isCancelled == true else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response: PexelsVideoResponse
            if let cat = selectedCategory {
                response = try await videoNetwork.fetchVideoSearch(query: cat, page: currentPage, perPage: 30)
            } else if let q = searchQuery, !q.isEmpty {
                response = try await videoNetwork.fetchVideoSearch(query: q, page: currentPage, perPage: 30)
            } else {
                response = try await videoNetwork.fetchPopularVideos(page: currentPage, perPage: 30)
            }

            let paginated = PaginatedResponse<VideoWallpaper>(response)
            if searchQuery != nil || selectedCategory != nil || !searchText.isEmpty {
                searchResults = paginated.results
            } else {
                if currentPage == 1 {
                    videos = paginated.results
                } else {
                    videos.append(contentsOf: paginated.results)
                }
            }
            hasNext = paginated.hasNext
            currentPage = paginated.page
            error = nil
        } catch {
            self.error = error
        }
    }
}
