import SwiftUI

// MARK: - Settings tab
struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                // Theme section
                Section("Appearance") {
                    Picker("Theme", selection: $viewModel.selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("App theme")
                    .accessibilityHint("Select light, dark, or system appearance")
                    .onChange(of: viewModel.selectedTheme) { _, new in
                        viewModel.updateTheme(new)
                    }
                }

                // Blur section
                Section("Preview") {
                    Picker("Blur Style", selection: $viewModel.blurMode) {
                        ForEach(BlurMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Blur style")
                    .accessibilityHint("Select blur effect for wallpaper preview")
                    .onChange(of: viewModel.blurMode) { _, new in
                        viewModel.updateBlurMode(new)
                    }

                    HStack {
                        Text("Blur Intensity")
                        Spacer()
                        Text("\(Int(viewModel.defaultBlur * 100))%")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Blur intensity \(Int(viewModel.defaultBlur * 100)) percent")
                }

                // Telegram sync section
                Section("Telegram Channel") {
                    Toggle("Sync from Telegram", isOn: Binding(
                        get: { viewModel.isTelegramSyncEnabled },
                        set: { viewModel.setTelegramSyncEnabled($0) }
                    ))
                    .accessibilityLabel("Sync wallpapers from Telegram")
                    .accessibilityHint("When enabled, fetches wallpapers from a Telegram channel")
                    .onChange(of: viewModel.isTelegramSyncEnabled) { _, newValue in
                        if newValue {
                            viewModel.showTelegramSetupInfo()
                        }
                    }

                    if viewModel.isTelegramSyncEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Source channel: @tessera_wallpapers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Set TESSERA_TELEGRAM_WORKER_URL in your environment or use --telegram-sync in DEBUG.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Source channel @tessera_wallpapers")
                    }
                }

                // Storage section
                Section("Data") {
                    Button(role: .destructive) {
                        viewModel.clearCache()
                    } label: {
                        HStack {
                            Text("Clear Image Cache")
                            Spacer()
                            if viewModel.cacheSize > 0 {
                                Text(formatBytes(viewModel.cacheSize))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .accessibilityLabel("Clear image cache")
                    .accessibilityHint("Frees up space by removing cached images")

                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("About")
                    }
                    .accessibilityLabel("About Tessera")
                }

                // Attribution
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tessera uses wallpapers from Pexels")
                            .font(.caption)
                        Link("Pexels License", destination: URL(string: "https://www.pexels.com/license/")!)
                            .font(.caption)
                        Link("Pexels API", destination: URL(string: "https://www.pexels.com/api/")!)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .task {
            await viewModel.computeCacheSize()
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Settings view model
@MainActor
final class SettingsViewModel: ObservableObject {
    let persistence: PersistenceStore
    let cache: FilterImageCache

    @Published var selectedTheme: AppTheme
    @Published var blurMode: BlurMode
    @Published var defaultBlur: Double = 0.3
    @Published var cacheSize: Int64 = 0
    @Published var isTelegramSyncEnabled: Bool = false

    init(persistence: PersistenceStore, cache: FilterImageCache) {
        self.persistence = persistence
        self.cache = cache
        self.selectedTheme = persistence.selectedTheme
        self.blurMode = persistence.blurMode
        isTelegramSyncEnabled = false
    }

    func setTelegramSyncEnabled(_ enabled: Bool) {
        isTelegramSyncEnabled = enabled
    }

    func showTelegramSetupInfo() {
        // In production, present a sheet or navigate to a setup screen
    }

    func updateTheme(_ theme: AppTheme) {
        persistence.selectedTheme = theme
        selectedTheme = theme
    }

    func updateBlurMode(_ mode: BlurMode) {
        persistence.blurMode = mode
        blurMode = mode
    }

    func clearCache() {
        cache.cache.removeAll()
        Task { await computeCacheSize() }
    }

    func computeCacheSize() async {
        cacheSize = Int64(cache.cache.count * 1_000_000)
    }
}

// MARK: - About view
struct AboutView: View {
    var body: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    Text("Tessera")
                        .font(.title.bold())
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                    Text("A wallpaper discovery app built for iOS.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            Section("Open Source") {
                Link("View on GitHub", destination: URL(string: "https://github.com/finch254/tessera")!)
                Link("Report an Issue", destination: URL(string: "https://github.com/finch254/tessera/issues")!)
            }

            Section("Third-party") {
                Link("Pexels API", destination: URL(string: "https://www.pexels.com/api/")!)
                Link("Pexels License", destination: URL(string: "https://www.pexels.com/license/")!)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let persistence = UserDefaultsPersistenceStore()
    let cache = FilterImageCache()
    let vm = SettingsViewModel(persistence: persistence, cache: cache)
    return SettingsView(viewModel: vm)
}
