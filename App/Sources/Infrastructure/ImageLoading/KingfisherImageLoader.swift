import Foundation
import UIKit
import Kingfisher

final class KingfisherImageLoader: ImageLoadingService {
    private let cache: ImageCache

    init(cache: ImageCache = .default) {
        self.cache = cache
    }

    func load(url: URL) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let task = KingfisherManager.shared.retrieveImage(with: url, options: [.cacheOriginalImage]) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value.image)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            // Store task if we need cancellation later
        }
    }

    func prefetch(urls: [URL]) {
        let prefetcher = ImagePrefetcher(urls: urls)
        prefetcher.start()
    }
}

// MARK: - In-memory image cache helper for filtering pipeline
final class FilterImageCache {
    // Cache decompressed UIImage by URL for filter pipeline use
    private var cache: [String: UIImage] = [:]
    private let lock = NSLock()

    func get(_ url: URL) -> UIImage? {
        lock.lock(); defer { lock.unlock() }
        return cache[url.absoluteString]
    }

    func set(_ image: UIImage, for url: URL) {
        lock.lock(); defer { lock.unlock() }
        cache[url.absoluteString] = image
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        cache.removeAll()
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return cache.count
    }
}
