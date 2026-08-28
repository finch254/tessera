import SwiftUI
import Kingfisher

struct VideoDiscoverView: View {
    @ObservedObject var viewModel: VideoDiscoverViewModel

    @State private var searchText = ""
    @State private var selectedVideo: VideoWallpaper?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .center) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            videoCategoryChips
                                .padding(.horizontal)
                                .padding(.top, 8)

                            videoMasonryGrid
                                .padding(.horizontal)
                        }
                        .padding(.bottom, 24)
                    }
                    .onChange(of: viewModel.selectedCategory) { _ in
                        Task { await viewModel.resetAndFetch() }
                    }
                }

                if viewModel.isLoading && viewModel.videos.isEmpty && viewModel.searchResults.isEmpty {
                    loadingView
                } else if let message = viewModel.errorMessage,
                          viewModel.videos.isEmpty && viewModel.searchResults.isEmpty {
                    errorView(message: message)
                }
            }
            .navigationTitle("Videos")
            .searchable(text: $searchText, prompt: "Search video wallpapers")
            .onChange(of: searchText) { newValue in
                viewModel.searchText = newValue
                Task { await viewModel.search(query: newValue) }
            }
            .sheet(item: $selectedVideo) { video in
                VideoDetailHost(video: video, coordinator: viewModel.coordinator)
            }
        }
    }

    // MARK: - Category chips
    private var videoCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.categories, id: \.id) { category in
                    let selected = viewModel.selectedCategory == category.id
                    Text(category.name)
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selected ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundStyle(selected ? .white : .primary)
                        .clipShape(Capsule())
                        .accessibilityLabel("\(category.name) video category")
                        .accessibilityHint(selected ? "Active, tap to remove" : "Tap to filter by \(category.name)")
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                viewModel.selectCategory(category.id)
                            }
                        }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Masonry grid
    private var videoMasonryGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10),
        ]
        let items = viewModel.displayedVideos

        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { video in
                videoMasonryCell(video: video)
                    .onAppear {
                        let index = items.firstIndex(where: { $0.id == video.id }) ?? 0
                        viewModel.onItemAppeared(at: index)
                    }
            }
        }
    }

    private func videoMasonryCell(video: VideoWallpaper) -> some View {
        let aspectRatio = CGFloat(video.height) / max(CGFloat(video.width), 1)
        let width: CGFloat = 180
        let height = width / max(aspectRatio, 0.5)

        return ZStack(alignment: .center) {
            KFImage(video.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipped()
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Play icon overlay
            VStack(spacing: 4) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.9))
                Text("Video")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(video.photographer)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedVideo = video
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Video wallpaper by \(video.photographer)")
        .accessibilityHint("Tap to view and save as Live Photo")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - States
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            Text("Loading videos…")
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
            .accessibilityLabel("Retry loading videos")
        }
        .padding()
    }
}

// MARK: - Video detail host bridge
struct VideoDetailHost: UIViewControllerRepresentable {
    let video: VideoWallpaper
    let coordinator: WallpaperDetailCoordinator?

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let coordinator = coordinator,
              uiViewController.presentedViewController == nil else { return }
        coordinator.rootViewController = uiViewController
        coordinator.showVideoDetail(for: video)
    }

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Void) {
        uiViewController.presentedViewController?.dismiss(animated: false)
    }
}
