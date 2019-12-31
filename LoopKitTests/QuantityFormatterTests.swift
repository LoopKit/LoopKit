//
//  QuantityFormatterTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit

class QuantityFormatterTests: XCTestCase {

    var formatter: QuantityFormatter!

    override func setUp() {
        super.setUp()

        formatter = QuantityFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitStyle = .medium
    }

    func testInsulin() {
        let unit = HKUnit.internationalUnit()

        XCTAssertEqual("U", formatter.string(from: unit))
        XCTAssertEqual("10 U", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)

        formatter.unitStyle = .short

        XCTAssertEqual("U", formatter.string(from: unit))
        XCTAssertEqual("10U", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)

        formatter.unitStyle = .long

        XCTAssertEqual("Units", formatter.string(from: unit))
        XCTAssertEqual("10 Units", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)
    }

    func testInsulinRates() {
        let unit = HKUnit.internationalUnit().unitDivided(by: .hour())

        XCTAssertEqual("U/hr", formatter.string(from: unit))
        XCTAssertEqual("10 U/hr", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)

        formatter.unitStyle = .short

        XCTAssertEqual("U/hr", formatter.string(from: unit))
        XCTAssertEqual("10U/hr", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)

        formatter.unitStyle = .long

        XCTAssertEqual("Units/hour", formatter.string(from: unit))
        XCTAssertEqual("10 Units/hour", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)

        XCTAssertEqual("1 Unit/hour", formatter.string(from: HKQuantity(unit: unit, doubleValue: 1), for: unit)!)
    }

    func testCarbs() {
        let unit = HKUnit.gram()

        XCTAssertEqual("g", formatter.string(from: unit))
        XCTAssertEqual("10 g", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)

        formatter.unitStyle = .short

        XCTAssertEqual("g", formatter.string(from: unit))
        XCTAssertEqual("10g", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)

        formatter.unitStyle = .long

        XCTAssertEqual("grams", formatter.string(from: unit))
        XCTAssertEqual("10 grams", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)
        XCTAssertEqual("0 grams", formatter.string(from: HKQuantity(unit: unit, doubleValue: 0), for: unit)!)
        XCTAssertEqual("1 gram", formatter.string(from: HKQuantity(unit: unit, doubleValue: 1), for: unit)!)

        formatter.numberFormatter.formattingContext = .standalone

        XCTAssertEqual("10 grams", formatter.string(from: HKQuantity(unit: unit, doubleValue: 10), for: unit)!)
    }

    func testGlucoseMGDL() {
        let unit = HKUnit.milligramsPerDeciliter

        XCTAssertEqual("mg/dL", formatter.string(from: unit))
        XCTAssertEqual("60 mg/dL", formatter.string(from: HKQuantity(unit: unit, doubleValue: 60), for: unit)!)
        XCTAssertEqual("180 mg/dL", formatter.string(from: HKQuantity(unit: unit, doubleValue: 180), for: unit)!)

        formatter.unitStyle = .short

        XCTAssertEqual("mg/dL", formatter.string(from: unit))
        XCTAssertEqual("60mg/dL", formatter.string(from: HKQuantity(unit: unit, doubleValue: 60), for: unit)!)
        XCTAssertEqual("180mg/dL", formatter.string(from: HKQuantity(unit: unit, doubleValue: 180), for: unit)!)

        formatter.unitStyle = .long

        XCTAssertEqual("milligrams per deciliter", formatter.string(from: unit))
        XCTAssertEqual("180 milligrams per deciliter", formatter.string(from: HKQuantity(unit: unit, doubleValue: 180), for: unit)!)
        XCTAssertEqual("0 milligrams per deciliter", formatter.string(from: HKQuantity(unit: unit, doubleValue: 0), for: unit)!)
        XCTAssertEqual("1 milligrams per deciliter", formatter.string(from: HKQuantity(unit: unit, doubleValue: 1), for: unit)!)
    }

    func testGlucoseMMOLL() {
        let unit = HKUnit.millimolesPerLiter
        formatter.setPreferredNumberFormatter(for: unit)

        XCTAssertEqual("mmol/L", formatter.string(from: unit))
        XCTAssertEqual("6.0 mmol/L", formatter.string(from: HKQuantity(unit: unit, doubleValue: 6), for: unit)!)
        XCTAssertEqual("7.8 mmol/L", formatter.string(from: HKQuantity(unit: unit, doubleValue: 7.84), for: unit)!)
        XCTAssertEqual("12.0 mmol/L", formatter.string(from: HKQuantity(unit: unit, doubleValue: 12), for: unit)!)

        formatter.unitStyle = .short

        XCTAssertEqual("mmol/L", formatter.string(from: unit))
        XCTAssertEqual("6.0mmol/L", formatter.string(from: HKQuantity(unit: unit, doubleValue: 6), for: unit)!)
        XCTAssertEqual("7.8mmol/L", formatter.string(from: HKQuantity(unit: unit, doubleValue: 7.8), for: unit)!)

        formatter.unitStyle = .long

        XCTAssertEqual("millimoles per liter", formatter.string(from: unit))
        XCTAssertEqual("5.5 millimoles per liter", formatter.string(from: HKQuantity(unit: unit, doubleValue: 5.5), for: unit)!)
        XCTAssertEqual("0.0 millimoles per liter", formatter.string(from: HKQuantity(unit: unit, doubleValue: 0), for: unit)!)
        XCTAssertEqual("1.0 millimoles per liter", formatter.string(from: HKQuantity(unit: unit, doubleValue: 1), for: unit)!)
    }
}
