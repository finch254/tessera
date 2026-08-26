import XCTest
@testable import Tessera

final class FilterEngineTests: XCTestCase {
    private let engine = FilterEngine()

    func testMakeFiltersReturnsFifteenFilters() {
        let filters = FilterEngine.makeFilters()
        XCTAssertEqual(filters.count, 18, "FilterEngine should provide 18 filters")
    }

    func testApplyFilterReturnsNonNilImage() {
        let filters = FilterEngine.makeFilters()
        guard let ciImage = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100)) else {
            XCTFail("Could not create test CIImage")
            return
        }
        let result = filters[0].apply(ciImage)
        XCTAssertNotNil(result, "Applying first filter should return an image")
    }

    func testBlurDoesNotCrashOnNilInput() {
        // applyBlur with nil image returns nil, no crash
        let result = engine.applyBlur(to: nil, radius: 5.0, mode: .gaussian)
        XCTAssertNil(result, "Blur on nil input should return nil")
    }
}
