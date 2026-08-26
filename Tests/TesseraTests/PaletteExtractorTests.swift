import XCTest
@testable import Tessera

final class PaletteExtractorTests: XCTestCase {
    func testExtractReturnsUpToFiveColors() async {
        // Create a 100x100 solid color image
        let size = CGSize(width: 100, height: 100)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.red.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let uiImage = image else {
            XCTFail("Could not create test image")
            return
        }

        let colors = await PaletteExtractor.extract(from: uiImage, maximumColorCount: 5)
        XCTAssertFalse(colors.isEmpty, "Should extract at least one color from a solid image")
        XCTAssertLessThanOrEqual(colors.count, 5, "Should return at most 5 colors")
    }
}
