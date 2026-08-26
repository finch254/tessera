import SwiftUI
import Kingfisher

// MARK: - Discover tab (masonry grid browse)
struct DiscoverView: View {
    @StateObject private var viewModel: DiscoverViewModel
    @Environment(\.colorScheme) private var systemColorScheme

    init(viewModel: DiscoverViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Category chips
                    categoriesRow

                    // Masonry grid
                    masonryGrid
                }
                .padding(.bottom, 80)
            }
            .navigationTitle("Explore")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SearchView(viewModel: viewModel)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.wallpapers.isEmpty {
                    ProgressView()
                }
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("Retry") {
                    Task { await viewModel.refresh() }
                }
                Button("Cancel", role: .cancel) { viewModel.error = nil }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Category row
    private var categoriesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.categories) { category in
                    CategoryChip(category: category)
                        .onTapGesture {
                            Task { await viewModel.selectCategory(category) }
                        }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Masonry grid
    private var masonryGrid: some View {
        LazyVGrid(columns: masonryColumns, spacing: 2) {
            ForEach(viewModel.wallpapers) { wallpaper in
                WallpaperGridCell(wallpaper: wallpaper)
                    .onTapGesture {
                        viewModel.selectedWallpaper = wallpaper
                    }
            }
        }
        .padding(.horizontal, 2)
    }

    private var masonryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 2)
    }
}

// MARK: - Category chip
struct CategoryChip: View {
    let category: WallpaperCategory
    var isSelected: Bool = false

    var body: some View {
        Text(category.name)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay {
                if isSelected {
                    Capsule().stroke(Color.accentColor, lineWidth: 1)
                }
            }
    }
}

// MARK: - Wallpaper grid cell
struct WallpaperGridCell: View {
    let wallpaper: Wallpaper

    var body: some View {
        ZStack(alignment: .bottom) {
            KFImage(wallpaper.src.medium)
                .placeholder {
                    Color.gray.opacity(0.3)
                        .overlay(ProgressView())
                }
                .onSuccess { response in
                    // Prefetch larger versions
                    let urls = [wallpaper.src.large, wallpaper.src.large2x].compactMap { $0 }
                    KingfisherManager.shared.retrieveImageStream(with: urls, options: [.cacheOriginalImage])
                }
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .clipped()

            // Gradient overlay for text legibility
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)

            // Photographer attribution
            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.photographer)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                Text("\(wallpaper.width) × \(wallpaper.height)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(8)
            .background(Color.black.opacity(0.4).clipShape(RoundedRectangle(cornerRadius: 6)))
        }
        .aspectRatio(16/9, contentComparison: .priority)
    }
}

// MARK: - Search view
struct SearchView: View {
    @ObservedObject var viewModel: DiscoverViewModel
    @State private var query = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search wallpapers", text: $query)
                    .focused($focused)
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.search(query: query) }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                        Task { await viewModel.reset() }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            ScrollView {
                LazyVGrid(columns: masonryColumns, spacing: 2) {
                    ForEach(viewModel.searchResults) { wallpaper in
                        WallpaperGridCell(wallpaper: wallpaper)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var masonryColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: 2)
    }
}
