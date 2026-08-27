import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Daily Wallpaper Live Activity Widget
@available(iOS 16.2, *)
struct DailyWallpaperActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyWallpaperAttributes.self) { context in
            // MARK: Lock Screen Presentation (primary surface)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Daily Wallpaper", systemImage: "sun.max.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if context.isStale {
                        Text("Updating...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(context.state.photographer)
                    .font(.headline)
                    .lineLimit(1)

                Text("Tap Tessera to view today's wallpaper")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding()
        } dynamicIsland: { context in
            // MARK: Dynamic Island (only visible on iPhone 14 Pro+)
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Wallpaper")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(context.state.photographer)
                            .font(.headline)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "sun.max.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
            } compactLeading: {
                Image(systemName: "sun.max.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            } compactTrailing: {
                Text(context.state.photographer)
                    .font(.caption2)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "sun.max.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            .keylineTint(.accentColor)
        }
    }
}
