import ActivityKit
import Foundation
import UIKit

// MARK: - Daily Wallpaper Live Activity
// Shows the daily wallpaper on the Lock Screen and Dynamic Island
// (Dynamic Island only on iPhone 14 Pro and newer)

struct DailyWallpaperAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let wallpaperID: String
        let photographer: String
        let imageURL: String
        let updatedAt: Date
    }
}

@MainActor
enum DailyWallpaperActivityManager {
    static private var currentActivity: Activity<DailyWallpaperAttributes>?

    /// Request a Live Activity for the daily wallpaper.
    /// Falls back gracefully on devices without Dynamic Island.
    static func startActivity(wallpaper: Wallpaper) async {
        // Check authorization first
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled for this app")
            return
        }

        // End previous activity if it exists
        if let existing = currentActivity {
            await endActivity(existing)
        }

        let attributes = DailyWallpaperAttributes()
        let state = DailyWallpaperAttributes.ContentState(
            wallpaperID: wallpaper.id,
            photographer: wallpaper.photographer,
            imageURL: wallpaper.src.medium?.absoluteString ?? "",
            updatedAt: Date()
        )

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(86_400), // 24 hours
            relevanceScore: 80
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivity = activity
            print("Live Activity started: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    /// Update the daily wallpaper Live Activity
    static func updateActivity(wallpaper: Wallpaper) async {
        guard let activity = currentActivity else { return }

        let state = DailyWallpaperAttributes.ContentState(
            wallpaperID: wallpaper.id,
            photographer: wallpaper.photographer,
            imageURL: wallpaper.src.medium?.absoluteString ?? "",
            updatedAt: Date()
        )

        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(86_400),
            relevanceScore: 80
        )

        do {
            try await activity.update(content)
        } catch {
            print("Failed to update Live Activity: \(error)")
        }
    }

    /// End the current Live Activity
    static func endActivity(_ activity: Activity<DailyWallpaperAttributes>? = nil) async {
        let target = activity ?? currentActivity
        guard let target = target else { return }

        let finalState = DailyWallpaperAttributes.ContentState(
            wallpaperID: target.content.state.wallpaperID,
            photographer: target.content.state.photographer,
            imageURL: target.content.state.imageURL,
            updatedAt: target.content.state.updatedAt
        )

        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil,
            relevanceScore: 0
        )

        do {
            try await target.end(finalContent, dismissalPolicy: .default)
            if target.id == currentActivity?.id {
                currentActivity = nil
            }
        } catch {
            print("Failed to end Live Activity: \(error)")
        }
    }

    /// Check if Live Activities are supported on this device
    static var isSupported: Bool {
        if #available(iOS 16.2, *) {
            return true
        } else {
            return false
        }
    }

    /// Check if this device has Dynamic Island (iPhone 14 Pro+)
    static var hasDynamicIsland: Bool {
        // Check via device model identifier
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }

        // iPhone 14 Pro models and newer
        let dynamicIslandModels = [
            "iPhone15,2", "iPhone15,3", // iPhone 14 Pro / Pro Max
            "iPhone16,1", "iPhone16,2", // iPhone 15 Pro / Pro Max
            "iPhone17,1", "iPhone17,2", "iPhone17,3", "iPhone17,4", // iPhone 16 series
        ]

        return dynamicIslandModels.contains(identifier)
    }
}
