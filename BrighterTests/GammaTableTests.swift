import XCTest
@testable import Brighter

final class GammaTableTests: XCTestCase {

    // MARK: - Linear Table

    func testLinearTableHasCorrectSize() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertEqual(table.count, 256)
    }

    func testLinearTableStartsAtZero() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertEqual(table[0], 0.0, accuracy: 0.001)
    }

    func testLinearTableEndsAtOne() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertEqual(table[255], 1.0, accuracy: 0.001)
    }

    func testLinearTableIsMonotonicallyIncreasing() {
        let table = GammaTable.generateLinearTable(size: 256)
        for i in 1..<table.count {
            XCTAssertGreaterThan(table[i], table[i - 1], "Entry \(i) should be greater than entry \(i - 1)")
        }
    }

    func testLinearTableMidpointIsHalf() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertEqual(table[127], 127.0 / 255.0, accuracy: 0.01)
    }

    // MARK: - Boosted Table

    func testBoostedTableWithFactor1EqualsLinear() {
        let linear = GammaTable.generateLinearTable(size: 256)
        let boosted = GammaTable.generateBoostedTable(boostFactor: 1.0, size: 256)
        XCTAssertEqual(linear.count, boosted.count)
        for i in 0..<linear.count {
            XCTAssertEqual(linear[i], boosted[i], accuracy: 0.001, "Mismatch at index \(i)")
        }
    }

    func testBoostedTableEndsAtBoostFactor() {
        let boostFactor = 1.4
        let table = GammaTable.generateBoostedTable(boostFactor: boostFactor, size: 256)
        XCTAssertEqual(table[255], boostFactor, accuracy: 0.001)
    }

    func testBoostedTableStartsAtZero() {
        let table = GammaTable.generateBoostedTable(boostFactor: 1.4, size: 256)
        XCTAssertEqual(table[0], 0.0, accuracy: 0.001)
    }

    func testBoostedTableIsMonotonicallyIncreasing() {
        let table = GammaTable.generateBoostedTable(boostFactor: 1.3, size: 256)
        for i in 1..<table.count {
            XCTAssertGreaterThan(table[i], table[i - 1], "Entry \(i) should be greater than entry \(i - 1)")
        }
    }

    func testBoostedTableAtMaxBoost() {
        let table = GammaTable.generateBoostedTable(boostFactor: Constants.maxBoost, size: 256)
        XCTAssertEqual(table[255], Constants.maxBoost, accuracy: 0.001)
    }

    // MARK: - Boosted Triple Tables

    func testBoostedTablesAreIdentical() {
        let (red, green, blue) = GammaTable.generateBoostedTables(boostFactor: 1.3, size: 256)
        XCTAssertEqual(red.count, 256)
        XCTAssertEqual(green.count, 256)
        XCTAssertEqual(blue.count, 256)
        for i in 0..<256 {
            XCTAssertEqual(red[i], green[i], accuracy: 0.001, "Red/Green mismatch at \(i)")
            XCTAssertEqual(green[i], blue[i], accuracy: 0.001, "Green/Blue mismatch at \(i)")
        }
    }

    // MARK: - Validation

    func testValidateValidLinearTable() {
        let table = GammaTable.generateLinearTable(size: 256)
        XCTAssertTrue(GammaTable.validateTable(table))
    }

    func testValidateValidBoostedTable() {
        let table = GammaTable.generateBoostedTable(boostFactor: 1.3, size: 256)
        XCTAssertTrue(GammaTable.validateTable(table))
    }

    func testValidateEmptyTableFails() {
        XCTAssertFalse(GammaTable.validateTable([]))
    }

    func testValidateWrongSizeTableFails() {
        let table = GammaTable.generateLinearTable(size: 128)
        XCTAssertFalse(GammaTable.validateTable(table))
    }
}
