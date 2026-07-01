import XCTest
@testable import Brighter

final class ModelTests: XCTestCase {

    // MARK: - BrightnessState

    func testBrightnessStateNotBoosted() {
        let state = BrightnessState(systemBrightness: 0.8, boostFactor: 1.0)
        XCTAssertFalse(state.isBoosted)
        XCTAssertEqual(state.effectiveBrightness, 0.8)
    }

    func testBrightnessStateBoosted() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 1.3)
        XCTAssertTrue(state.isBoosted)
        XCTAssertEqual(state.effectiveBrightness, 1.3, accuracy: 0.01)
    }

    func testBrightnessStateBoostClampsToMax() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 2.0)
        XCTAssertTrue(state.isBoosted)
        XCTAssertEqual(state.boostFactor, Constants.maxBoost)
    }

    func testBrightnessStateBoostClampsToMin() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 0.5)
        XCTAssertFalse(state.isBoosted)
        XCTAssertEqual(state.boostFactor, Constants.minBoost)
    }

    func testIncrementBoost() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 1.0)
        let incremented = state.incrementBoost()
        XCTAssertEqual(incremented.boostFactor, 1.0 + Constants.boostStep, accuracy: 0.001)
    }

    func testIncrementBoostClampsAtMax() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: Constants.maxBoost - 0.01)
        let incremented = state.incrementBoost()
        XCTAssertEqual(incremented.boostFactor, Constants.maxBoost, accuracy: 0.001)
    }

    func testDecrementBoost() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 1.12)
        let decremented = state.decrementBoost()
        XCTAssertEqual(decremented.boostFactor, 1.12 - Constants.boostStep, accuracy: 0.001)
    }

    func testDecrementBoostStopsAtMin() {
        let state = BrightnessState(systemBrightness: 1.0, boostFactor: 1.0 + Constants.boostStep * 0.5)
        let decremented = state.decrementBoost()
        XCTAssertEqual(decremented.boostFactor, Constants.minBoost, accuracy: 0.001)
    }

    // MARK: - DisplayInfo

    func testDisplayInfoHDR() {
        let info = DisplayInfo(displayID: 1, isHDR: true, name: "Built-in XDR", peakLuminance: 1600)
        XCTAssertTrue(info.isHDR)
        XCTAssertEqual(info.name, "Built-in XDR")
        XCTAssertEqual(info.peakLuminance, 1600)
    }

    func testDisplayInfoNonHDR() {
        let info = DisplayInfo(displayID: 2, isHDR: false, name: "External Monitor", peakLuminance: nil)
        XCTAssertFalse(info.isHDR)
        XCTAssertNil(info.peakLuminance)
    }
}
