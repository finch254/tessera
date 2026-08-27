import Foundation
import UIKit

// MARK: - Mock image loader for previews and development
final class MockImageLoader: ImageLoadingService {
    func load(url: URL) async throws -> UIImage {
        // Return a 1x1 placeholder image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        return renderer.image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    func prefetch(urls: [URL]) {
        // no-op in mock
    }
}

// MARK: - Mock network service for development without API key
final class MockNetworkService: WallpaperNetworkService {
    private let mockWallpapers: [Wallpaper] = [
        .init(id: "1", photographer: "Alexander Milov", photographerId: "1", width: 4928, height: 3264,
              avgColor: "#2a3b4c", src: PexelsImageURLs(from: [
                "raw": "https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "large2x": "https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg?auto=compress&cs=tinysrgb&w=2560&h=1440&dpr=2",
                "large": "https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "medium": "https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg?auto=compress&cs=tinysrgb&w=600&h=400&dpr=1",
                "small": "https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg?auto=compress&cs=tinysrgb&w=400&h=260&dpr=1",
                "portrait": "",
                "landscape": "",
                "tiny": "https://images.pexels.com/photos/417074/pexels-photo-417074.jpeg?auto=compress&cs=tinysrgb&w=200&h=133&dpr=1"
              ]), alt: "Couple in field", liked: nil),
        .init(id: "2", photographer: "Pixabay", photographerId: "2", width: 5472, height: 3648,
              avgColor: "#1a1a2e", src: PexelsImageURLs(from: [
                "raw": "https://images.pexels.com/photos/1105731/pexels-photo-1105731.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "large2x": "",
                "large": "https://images.pexels.com/photos/1105731/pexels-photo-1105731.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "medium": "https://images.pexels.com/photos/1105731/pexels-photo-1105731.jpeg?auto=compress&cs=tinysrgb&w=600&h=400&dpr=1",
                "small": "https://images.pexels.com/photos/1105731/pexels-photo-1105731.jpeg?auto=compress&cs=tinysrgb&w=400&h=260&dpr=1",
                "portrait": "", "landscape": "", "tiny": ""
              ]), alt: "City skyline", liked: nil),
        .init(id: "3", photographer: "Unsplash", photographerId: "3", width: 4000, height: 6000,
              avgColor: "#fff5e6", src: PexelsImageURLs(from: [
                "raw": "https://images.pexels.com/photos/2089846/pexels-photo-2089846.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "large2x": "",
                "large": "https://images.pexels.com/photos/2089846/pexels-photo-2089846.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "medium": "https://images.pexels.com/photos/2089846/pexels-photo-2089846.jpeg?auto=compress&cs=tinysrgb&w=600&h=400&dpr=1",
                "small": "https://images.pexels.com/photos/2089846/pexels-photo-2089846.jpeg?auto=compress&cs=tinysrgb&w=400&h=260&dpr=1",
                "portrait": "", "landscape": "", "tiny": ""
              ]), alt: "Abstract art", liked: nil),
        .init(id: "4", photographer: "NASA", photographerId: "4", width: 4272, height: 2848,
              avgColor: "#0b0c10", src: PexelsImageURLs(from: [
                "raw": "https://images.pexels.com/photos/1040480/pexels-photo-1040480.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "large2x": "",
                "large": "https://images.pexels.com/photos/1040480/pexels-photo-1040480.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "medium": "https://images.pexels.com/photos/1040480/pexels-photo-1040480.jpeg?auto=compress&cs=tinysrgb&w=600&h=400&dpr=1",
                "small": "https://images.pexels.com/photos/1040480/pexels-photo-1040480.jpeg?auto=compress&cs=tinysrgb&w=400&h=260&dpr=1",
                "portrait": "", "landscape": "", "tiny": ""
              ]), alt: "Space", liked: nil),
        .init(id: "5", photographer: "Ansel Adams", photographerId: "5", width: 3000, height: 2000,
              avgColor: "#3d5a80", src: PexelsImageURLs(from: [
                "raw": "https://images.pexels.com/photos/3159679/pexels-photo-3159679.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "large2x": "",
                "large": "https://images.pexels.com/photos/3159679/pexels-photo-3159679.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "medium": "https://images.pexels.com/photos/3159679/pexels-photo-3159679.jpeg?auto=compress&cs=tinysrgb&w=600&h=400&dpr=1",
                "small": "https://images.pexels.com/photos/3159679/pexels-photo-3159679.jpeg?auto=compress&cs=tinysrgb&w=400&h=260&dpr=1",
                "portrait": "", "landscape": "", "tiny": ""
              ]), alt: "Mountain", liked: nil),
        .init(id: "6", photographer: "Colorlab", photographerId: "6", width: 5000, height: 5000,
              avgColor: "#f0e6d3", src: PexelsImageURLs(from: [
                "raw": "https://images.pexels.com/photos/3124944/pexels-photo-3124944.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "large2x": "",
                "large": "https://images.pexels.com/photos/3124944/pexels-photo-3124944.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "medium": "https://images.pexels.com/photos/3124944/pexels-photo-3124944.jpeg?auto=compress&cs=tinysrgb&w=600&h=400&dpr=1",
                "small": "https://images.pexels.com/photos/3124944/pexels-photo-3124944.jpeg?auto=compress&cs=tinysrgb&w=400&h=260&dpr=1",
                "portrait": "", "landscape": "", "tiny": ""
              ]), alt: "Minimal", liked: nil),
        .init(id: "7", photographer: "Wildlife", photographerId: "7", width: 4000, height: 3000,
              avgColor: "#2d5016", src: PexelsImageURLs(from: [
                "raw": "https://images.pexels.com/photos/4520165/pexels-photo-4520165.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "large2x": "",
                "large": "https://images.pexels.com/photos/4520165/pexels-photo-4520165.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "medium": "https://images.pexels.com/photos/4520165/pexels-photo-4520165.jpeg?auto=compress&cs=tinysrgb&w=600&h=400&dpr=1",
                "small": "https://images.pexels.com/photos/4520165/pexels-photo-4520165.jpeg?auto=compress&cs=tinysrgb&w=400&h=260&dpr=1",
                "portrait": "", "landscape": "", "tiny": ""
              ]), alt: "Animals", liked: nil),
        .init(id: "8", photographer: "TextureLab", photographerId: "8", width: 4000, height: 4000,
              avgColor: "#8b7355", src: PexelsImageURLs(from: [
                "raw": "https://images.pexels.com/photos/5318361/pexels-photo-5318361.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "large2x": "",
                "large": "https://images.pexels.com/photos/5318361/pexels-photo-5318361.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
                "medium": "https://images.pexels.com/photos/5318361/pexels-photo-5318361.jpeg?auto=compress&cs=tinysrgb&w=600&h=400&dpr=1",
                "small": "https://images.pexels.com/photos/5318361/pexels-photo-5318361.jpeg?auto=compress&cs=tinysrgb&w=400&h=260&dpr=1",
                "portrait": "", "landscape": "", "tiny": ""
              ]), alt: "Textures", liked: nil),
    ]

    func fetchPopular(page: Int, perPage: Int) async throws -> PaginatedResponse<Wallpaper> {
        try await Task.sleep(for: .milliseconds(300))
        let start = (page - 1) * perPage
        let end = min(start + perPage, mockWallpapers.count)
        let results = Array(mockWallpapers[start..<end])
        return PaginatedResponse(
            totalResults: mockWallpapers.count,
            page: page,
            perPage: perPage,
            results: results,
            hasNext: end < mockWallpapers.count
        )
    }

    func fetchSearch(query: String?, page: Int, perPage: Int) async throws -> PaginatedResponse<Wallpaper> {
        try await fetchPopular(page: page, perPage: perPage)
    }

    func fetchCategory(slug: String, page: Int, perPage: Int) async throws -> PaginatedResponse<Wallpaper> {
        try await fetchPopular(page: page, perPage: perPage)
    }
}
