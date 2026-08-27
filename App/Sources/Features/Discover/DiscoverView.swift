import SwiftUI

struct DiscoverView: View {
    @ObservedObject var viewModel: DiscoverViewModel

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack(alignment: .center) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            categoryChips
                                .padding(.horizontal)
                                .padding(.top, 8)

                            masonryGrid
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 24)
                    }
                    .onChange(of: viewModel.selectedCategories) { _, _ in
                        Task { await viewModel.resetAndFetch() }
                    }
                }

                if viewModel.isLoading && viewModel.wallpapers.isEmpty && viewModel.searchResults.isEmpty {
                    loadingView
                } else if let message = viewModel.errorMessage,
                          viewModel.wallpapers.isEmpty && viewModel.searchResults.isEmpty {
                    errorView(message: message)
                }
            }
            .navigationTitle("Explore")
            .searchable(text: $searchText, prompt: "Search wallpapers")
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
                Task { await viewModel.search(query: newValue) }
            }
            .sheet(item: Binding<Wallpaper?>(
                get: { nil },
                set: { wallpaper in
                    if let w = wallpaper {
                        viewModel.coordinator.rootViewController = getRoot()
                        viewModel.coordinator.showDetail(for: w)
                    }
                }
            )) { _ in
                EmptyView()
            }
        }
    }

    // MARK: - Category chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.categories, id: \.id) { category in
                    let selected = viewModel.selectedCategories.contains(category.id)
                    Text(category.name)
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selected ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundStyle(selected ? .white : .primary)
                        .clipShape(Capsule())
                        .accessibilityLabel("\(category.name) category")
                        .accessibilityHint(selected ? "Active, tap to remove" : "Tap to filter by \(category.name)")
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                viewModel.toggleCategory(category.id)
                            }
                        }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Masonry grid
    private var masonryGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]
        let items = viewModel.displayedWallpapers

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { wallpaper in
                masonryCell(wallpaper: wallpaper)
                    .onAppear {
                        let index = items.firstIndex(where: { $0.id == wallpaper.id }) ?? 0
                        viewModel.onItemAppeared(at: index)
                    }
            }
        }
    }

    @ViewBuilder
    private func masonryCell(wallpaper: Wallpaper) -> some View {
        let aspectRatio = (wallpaper.height as CGFloat) / max(wallpaper.width as CGFloat, 1)
        let width: CGFloat = 180
        let height = width / max(aspectRatio, 0.5)

        ZStack(alignment: .bottomLeading) {
            if let url = wallpaper.src.medium {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.gray.opacity(0.4))
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.photographer)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if viewModel.isFavorite(wallpaper) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Wallpaper by \(wallpaper.photographer)")
        .accessibilityHint("Tap to view and customize")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - States
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            Text("Loading wallpapers…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.resetAndFetch() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Retry loading wallpapers")
        }
        .padding()
    }

    // MARK: - Helpers
    private func getRoot() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            return nil
        }
        return root.topMostViewController()
    }
}

// MARK: - Detail host bridge
struct DetailHost: UIViewControllerRepresentable {
    let wallpaper: Wallpaper
    let coordinator: WallpaperDetailCoordinator?

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let coordinator = coordinator,
              uiViewController.presentedViewController == nil else { return }
        coordinator.rootViewController = uiViewController
        coordinator.showDetail(for: wallpaper)
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Void) {
        uiViewController.presentedViewController?.dismiss(animated: false)
    }
}

#Preview {
    let persistence = UserDefaultsPersistenceStore()
    let coordinator = WallpaperDetailCoordinator()
    let viewModel = DiscoverViewModel(
        network: MockNetworkService(),
        imageLoader: KingfisherImageLoader(),
        persistence: persistence,
        coordinator: coordinator
    )
    return DiscoverView(viewModel: viewModel)
}

// MARK: - Detail host preview
#Preview("Detail Host") {
    let coordinator = WallpaperDetailCoordinator()
    let wallpaper = Wallpaper(
        id: "1", photographer: "Test", photographerId: "1",
        width: 1080, height: 1920, avgColor: nil,
        src: PexelsImageURLs(from: ["medium": "https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg"]),
        alt: nil, liked: false
    )
    return DetailHost(wallpaper: wallpaper, coordinator: coordinator)
}
