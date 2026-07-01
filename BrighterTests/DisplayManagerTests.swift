import XCTest
@testable import Brighter

final class DisplayManagerTests: XCTestCase {

    func testDetectOnlineDisplays() {
        let manager = DisplayManager()
        let displays = manager.allDisplays
        XCTAssertFalse(displays.isEmpty, "Should detect at least one display")
    }

    func testHDRDisplaysSubsetOfAllDisplays() {
        let manager = DisplayManager()
        let allDisplays = manager.allDisplays
        let hdrDisplays = manager.hdrDisplays
        for hdrDisplay in hdrDisplays {
            XCTAssertTrue(allDisplays.contains(where: { $0.displayID == hdrDisplay.displayID }),
                          "HDR display \(hdrDisplay.displayID) not found in all displays")
        }
    }

    func testSystemBrightnessInRange() {
        let manager = DisplayManager()
        guard let display = manager.allDisplays.first else {
            XCTFail("No displays found")
            return
        }
        let brightness = manager.systemBrightness(for: display.displayID)
        XCTAssertGreaterThanOrEqual(brightness, 0.0)
        XCTAssertLessThanOrEqual(brightness, 1.0)
    }
}
