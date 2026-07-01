import XCTest
@testable import Brighter

final class BrightnessEngineTests: XCTestCase {

    func testInitialBoostIsMin() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        XCTAssertEqual(engine.boostFactor, Constants.minBoost, accuracy: 0.001)
    }

    func testIncreaseBoost() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.increaseBoost()
        XCTAssertEqual(engine.boostFactor, Constants.minBoost + Constants.boostStep, accuracy: 0.001)
    }

    func testIncreaseBoostClampsAtMax() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.setBoost(Constants.maxBoost - 0.01)
        engine.increaseBoost()
        XCTAssertEqual(engine.boostFactor, Constants.maxBoost, accuracy: 0.001)
    }

    func testDecreaseBoost() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.setBoost(1.2)
        engine.decreaseBoost()
        XCTAssertEqual(engine.boostFactor, 1.2 - Constants.boostStep, accuracy: 0.001)
    }

    func testDecreaseBoostStopsAtMin() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.setBoost(Constants.minBoost + 0.01)
        engine.decreaseBoost()
        XCTAssertEqual(engine.boostFactor, Constants.minBoost, accuracy: 0.001)
    }

    func testResetBoost() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.setBoost(1.5)
        engine.resetBoost()
        XCTAssertEqual(engine.boostFactor, Constants.minBoost, accuracy: 0.001)
        XCTAssertFalse(engine.isBoosted)
    }

    func testIsBoostedReflectsState() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        XCTAssertFalse(engine.isBoosted)
        engine.setBoost(1.1)
        XCTAssertTrue(engine.isBoosted)
        engine.resetBoost()
        XCTAssertFalse(engine.isBoosted)
    }

    func testBoostFactorClampedToValidRange() {
        let engine = BrightnessEngine(displayManager: DisplayManager())
        engine.setBoost(0.5)
        XCTAssertEqual(engine.boostFactor, Constants.minBoost, accuracy: 0.001)
        engine.setBoost(3.0)
        XCTAssertEqual(engine.boostFactor, Constants.maxBoost, accuracy: 0.001)
    }
}
