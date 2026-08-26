import XCTest
@testable import Tessera

final class DiscoverViewModelTests: XCTestCase {
    private var viewModel: DiscoverViewModel!

    override func setUp() async throws {
        try await super.setUp()
        // Uses MockNetworkService because PEXELS_API_KEY is nil in tests
        let persistence = UserDefaultsPersistenceStore()
        let imageLoader = KingfisherImageLoader()
        let network = MockNetworkService()
        viewModel = DiscoverViewModel(network: network, imageLoader: imageLoader, persistence: persistence)
    }

    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
    }

    func testInitialWallpapersAreEmpty() async {
        // When initialized with no cached data, wallpapers should start empty
        XCTAssertTrue(viewModel.wallpapers.isEmpty, "Wallpapers should start empty before first fetch")
    }

    func testCategoriesArePopulated() async {
        XCTAssertFalse(viewModel.categories.isEmpty, "Categories should not be empty")
        XCTAssertTrue(viewModel.categories.contains("Nature"), "Categories should include Nature")
    }

    func testToggleCategoryFiltersWallpapers() async {
        // Toggle a category and verify it updates selected categories
        viewModel.toggleCategory("Nature")
        XCTAssertTrue(viewModel.selectedCategories.contains("Nature"))
        viewModel.toggleCategory("Nature")
        XCTAssertFalse(viewModel.selectedCategories.contains("Nature"))
    }
}
