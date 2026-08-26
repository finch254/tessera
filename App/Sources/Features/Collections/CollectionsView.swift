import SwiftUI

struct CollectionsView: View {
    @ObservedObject var viewModel: CollectionsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Daily wallpaper banner
                    if let daily = viewModel.daily {
                        dailyBanner(daily)
                            .padding(.horizontal)
                    }

                    // Collections grid
                    collectionsGrid
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Featured")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.collections.isEmpty {
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Daily Banner
    private func dailyBanner(_ daily: DailyWallpaper) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAILY WALLPAPER")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("Today's Pick")
                        .font(.title3.bold())
                }
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
            }

            // Preview image
            AsyncImageView(url: daily.wallpaper.src.medium, cornerRadius: 16)
                .frame(height: 200)
                .clipped()

            Button {
                // Will be handled by coordinator in production
            } label: {
                Label("Set as Wallpaper", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Collections Grid
    private var collectionsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]

        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.collections) { collection in
                collectionCard(collection)
            }
        }
    }

    private func collectionCard(_ collection: WallpaperCollection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImageView(url: collection.coverImageURL, cornerRadius: 12)
                .frame(height: 140)
                .clipped()
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.clear, lineWidth: 0)
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(collection.title)
                        .font(.headline)
                    if collection.isPremium {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(collection.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Async Image Loader (SFW)
struct AsyncImageView: View {
    let url: URL?
    let cornerRadius: CGFloat

    init(url: URL?, cornerRadius: CGFloat = 12) {
        self.url = url
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let url = url {
                // In production: KFImage(url) from Kingfisher
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.6))
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title)
                            .foregroundStyle(.gray.opacity(0.4))
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    let persistence = UserDefaultsPersistenceStore()
    let vm = CollectionsViewModel(network: MockNetworkService(), persistence: persistence)
    return CollectionsView(viewModel: vm)
}
