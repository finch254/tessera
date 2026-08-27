import XCTest
@testable import Tessera

@MainActor
final class DiscoverViewModelTests: XCTestCase {
    private var viewModel: DiscoverViewModel!

    override func setUp() async throws {
        try await super.setUp()
        let persistence = UserDefaultsPersistenceStore()
        let imageLoader = KingfisherImageLoader()
        let network = MockNetworkService()
        let coordinator = WallpaperDetailCoordinator(persistence: persistence)
        viewModel = DiscoverViewModel(network: network, imageLoader: imageLoader, persistence: persistence, coordinator: coordinator)
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    func testInitialWallpapersAreEmpty() async {
        XCTAssertTrue(viewModel.wallpapers.isEmpty, "Wallpapers should start empty before first fetch")
    }

    func testCategoriesArePopulated() async {
        XCTAssertFalse(viewModel.categories.isEmpty, "Categories should not be empty")
        XCTAssertTrue(viewModel.categories.contains { $0.name == "Nature" }, "Categories should include Nature")
    }

    func testToggleCategoryFiltersWallpapers() async {
        viewModel.toggleCategory("nature")
        XCTAssertTrue(viewModel.selectedCategories.contains("nature"))
        viewModel.toggleCategory("nature")
        XCTAssertFalse(viewModel.selectedCategories.contains("nature"))
    }
}
