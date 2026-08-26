import SwiftUI

struct DiscoverView: View {
    @ObservedObject var viewModel: DiscoverViewModel
    @State private var searchText = ""
    @State private var showingDetail = false
    @State private var selectedWallpaper: Wallpaper?

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
                        viewModel.resetAndFetch()
                    }
                }

                if viewModel.isLoading && viewModel.wallpapers.isEmpty {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage, viewModel.wallpapers.isEmpty {
                    errorView(message: errorMessage)
                }
            }
            .navigationTitle("Explore")
            .searchable(text: $searchText, prompt: "Search wallpapers")
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
                viewModel.resetAndFetch()
            }
            .sheet(item: $selectedWallpaper) { wallpaper in
                DetailHost(wallpaper: wallpaper, coordinator: viewModel.coordinator)
            }
            .task {
                await viewModel.loadNextPageIfNeeded()
            }
        }
    }

    // MARK: - Category chips
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.categories, id: \.self) { category in
                    let selected = viewModel.selectedCategories.contains(category)
                    Text(category)
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selected ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundStyle(selected ? .white : .primary)
                        .clipShape(Capsule())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                viewModel.toggleCategory(category)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Masonry grid
    private var masonryGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]
        let filtered = viewModel.filteredWallpapers(searchText: searchText)

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(filtered) { wallpaper in
                GeometryReader { geo in
                    masonryCell(wallpaper: wallpaper, width: geo.size.width)
                        .onAppear {
                            let index = filtered.firstIndex(where: { $0.id == wallpaper.id }) ?? 0
                            viewModel.onItemAppeared(at: index)
                        }
                        .onTapGesture {
                            selectedWallpaper = wallpaper
                        }
                }
                .frame(height: masonryHeight(for: wallpaper, width: geo.size.width))
            }
        }
    }

    @ViewBuilder
    private func masonryCell(wallpaper: Wallpaper, width: CGFloat) -> some View {
        let aspectRatio = (wallpaper.height as CGFloat) / max(wallpaper.width as CGFloat, 1)
        let height = width / max(aspectRatio, 0.5)

        ZStack(alignment: .bottomLeading) {
            if let urlString = wallpaper.thumbnailURL,
               let url = URL(string: urlString) {
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
                placeholderRect(width: width, height: height)
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
    }

    @ViewBuilder
    private func placeholderRect(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: height)
            .overlay(
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.gray.opacity(0.4))
            )
    }

    private func masonryHeight(for wallpaper: Wallpaper, width: CGFloat) -> CGFloat {
        let aspectRatio = (wallpaper.height as CGFloat) / max(wallpaper.width as CGFloat, 1)
        return width / max(aspectRatio, 0.5)
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
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    viewModel.errorMessage = nil
                    await viewModel.loadNextPageIfNeeded()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Detail host bridge (SwiftUI wraps UIKit detail VC)
struct DetailHost: UIViewControllerRepresentable {
    let wallpaper: Wallpaper
    let coordinator: WallpaperDetailCoordinator?

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Present the detail VC on top
        guard let coordinator = coordinator, uiViewController.presentedViewController == nil else { return }
        let model = WallpaperDetailModel(wallpaper: wallpaper)
        let detailVC = WallpaperDetailViewController.create(model: model)
        detailVC.modalPresentationStyle = .fullScreen
        uiViewController.present(detailVC, animated: true)
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Context) {
        // Dismiss if presented
        if let presented = uiViewController.presentedViewController {
            presented.dismiss(animated: false)
        }
    }
}

#Preview {
    let persistence = UserDefaultsPersistenceStore()
    let viewModel = DiscoverViewModel(
        network: MockNetworkService(),
        imageLoader: KingfisherImageLoader(),
        persistence: persistence
    )
    return DiscoverView(viewModel: viewModel)
}
