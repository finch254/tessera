import XCTest
@testable import Tessera

final class FilterEngineTests: XCTestCase {
    private let engine = FilterEngine()

    func testMakeFiltersReturnsEighteenFilters() {
        let filters = FilterEngine.makeFilters()
        XCTAssertEqual(filters.count, 18, "FilterEngine should provide 18 filters")
    }

    func testApplyFilterReturnsImage() {
        let filters = FilterEngine.makeFilters()
        let ciImage = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
        let result = filters[0].apply(ciImage)
        XCTAssertNotNil(result, "Applying first filter should return an image")
    }

    func testApplyFilterDoesNotCrashOnEmptyImage() {
        let filters = FilterEngine.makeFilters()
        let ciImage = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        let result = filters[0].apply(ciImage)
        XCTAssertNotNil(result, "Filter should handle small images")
    }
}
