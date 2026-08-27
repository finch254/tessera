import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Daily wallpaper home-screen widget
struct DailyWallpaperWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyWallpaperWidget", provider: DailyWallpaperProvider()) { entry in
            DailyWallpaperWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Wallpaper")
        .description("Today's featured wallpaper from Tessera.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Provider
struct DailyWallpaperProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyWallpaperEntry {
        DailyWallpaperEntry(date: Date(), imageURL: nil, title: "Daily Wallpaper")
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyWallpaperEntry) -> Void) {
        let entry = DailyWallpaperEntry(date: Date(), imageURL: nil, title: "Daily Wallpaper")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyWallpaperEntry>) -> Void) {
        // Fetch real daily wallpaper from Pexels
        Task {
            let entry = await fetchDailyWallpaper()
            // Refresh every 6 hours
            let entries: [DailyWallpaperEntry] = (0..<4).map { i in
                let date = Calendar.current.date(byAdding: .hour, value: i * 6, to: Date()) ?? Date()
                return DailyWallpaperEntry(date: date, imageURL: entry.imageURL, title: entry.title)
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    private func fetchDailyWallpaper() async -> DailyWallpaperEntry {
        // Fetch a curated/editor's choice wallpaper from Pexels
        guard let url = URL(string: "https://api.pexels.com/v1/curated?per_page=1&orientation=landscape") else {
            return DailyWallpaperEntry(date: Date(), imageURL: nil, title: "Daily Wallpaper")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Read API key from shared UserDefaults (App Group) or environment
        let apiKey = UserDefaults.standard.string(forKey: "pexels_api_key") 
            ?? ProcessInfo.processInfo.environment["PEXELS_API_KEY"] 
            ?? ""
        
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return DailyWallpaperEntry(date: Date(), imageURL: nil, title: "Daily Wallpaper")
            }

            // Parse the response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let photos = json["photos"] as? [[String: Any]],
               let first = photos.first,
               let src = first["src"] as? [String: Any],
               let mediumURL = src["medium"] as? String,
               let imageURL = URL(string: mediumURL) {
                let photographer = first["photographer"] as? String ?? "Tessera"
                return DailyWallpaperEntry(date: Date(), imageURL: imageURL, title: photographer)
            }
        } catch {
            print("Widget fetch error: \(error)")
        }

        return DailyWallpaperEntry(date: Date(), imageURL: nil, title: "Daily Wallpaper")
    }
}

// MARK: - Entry
struct DailyWallpaperEntry: TimelineEntry {
    let date: Date
    let imageURL: URL?
    let title: String
}

// MARK: - Widget view
struct DailyWallpaperWidgetView: View {
    var entry: DailyWallpaperEntry

    var body: some View {
        ZStack {
            if let url = entry.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
            } else {
                LinearGradient(
                    colors: [Color.black, Color.gray],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .overlay {
                    VStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Tessera")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    Text(entry.title)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    Spacer()
                }
                .padding(8)
            }
        }
        .widgetURL(URL(string: "tessera://daily"))
    }
}
