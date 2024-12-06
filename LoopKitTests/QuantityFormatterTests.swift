//
//  QuantityFormatterTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopAlgorithm
@testable import LoopKit

class QuantityFormatterTests: XCTestCase {

    var formatter: QuantityFormatter!

    func setFormatter(for unit: LoopUnit) {
        formatter = QuantityFormatter(for: unit)
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitStyle = .medium
        formatter.avoidLineBreaking = false
    }

    func testInsulin() {
        let unit = LoopUnit.internationalUnit
        setFormatter(for: unit)

        XCTAssertEqual("U", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10 U", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)

        formatter.unitStyle = .short

        XCTAssertEqual("U", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10U", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)

        formatter.unitStyle = .long

        XCTAssertEqual("Units", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10 Units", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)
    }

    func testInsulinRates() {
        let unit = LoopUnit.internationalUnitsPerHour
        setFormatter(for: unit)

        XCTAssertEqual("U/hr", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10 U/hr", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)

        formatter.unitStyle = .short

        XCTAssertEqual("U/hr", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10U/hr", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)

        formatter.unitStyle = .long

        XCTAssertEqual("Units/hour", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10 Units/hour", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)

        XCTAssertEqual("1 Unit/hour", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 1))!)
    }

    func testCarbs() {
        let unit = LoopUnit.gram
        setFormatter(for: unit)

        XCTAssertEqual("g", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10 g", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)

        formatter.unitStyle = .short

        XCTAssertEqual("g", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10g", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)

        formatter.unitStyle = .long

        XCTAssertEqual("grams", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10 grams", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)
        XCTAssertEqual("0 grams", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 0))!)
        XCTAssertEqual("1 gram", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 1))!)

        formatter.numberFormatter.formattingContext = .standalone

        XCTAssertEqual("10 grams", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10))!)
    }

    func testGlucoseMGDL() {
        let unit = LoopUnit.milligramsPerDeciliter
        setFormatter(for: unit)

        XCTAssertEqual("mg/dL", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("60 mg/dL", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 60))!)
        XCTAssertEqual("180 mg/dL", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 180))!)

        formatter.unitStyle = .short

        XCTAssertEqual("mg/dL", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("60mg/dL", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 60))!)
        XCTAssertEqual("180mg/dL", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 180))!)

        formatter.unitStyle = .long

        XCTAssertEqual("milligrams per deciliter", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("180 milligrams per deciliter", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 180))!)
        XCTAssertEqual("0 milligrams per deciliter", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 0))!)
        XCTAssertEqual("1 milligrams per deciliter", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 1))!)
    }

    func testGlucoseMMOLL() {
        let unit = LoopUnit.millimolesPerLiter
        setFormatter(for: unit)

        XCTAssertEqual("mmol/L", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("6.0 mmol/L", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 6))!)
        XCTAssertEqual("7.8 mmol/L", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 7.84))!)
        XCTAssertEqual("12.0 mmol/L", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 12))!)

        formatter.unitStyle = .short

        XCTAssertEqual("mmol/L", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("6.0mmol/L", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 6))!)
        XCTAssertEqual("7.8mmol/L", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 7.8))!)

        formatter.unitStyle = .long

        XCTAssertEqual("millimoles per liter", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("5.5 millimoles per liter", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 5.5))!)
        XCTAssertEqual("0.0 millimoles per liter", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 0))!)
        XCTAssertEqual("1.0 millimoles per liter", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 1))!)
    }

    func testGlucoseRates() {
        var unit = LoopUnit.millimolesPerLiterPerMinute
        setFormatter(for: unit)

        XCTAssertEqual("mmol/L/min", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("0.5 mmol/L/min", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 0.5))!)
        XCTAssertEqual("0.8 mmol/L/min", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 0.8))!)
        XCTAssertEqual("1.5 mmol/L/min", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 1.5))!)

        unit = LoopUnit.milligramsPerDeciliterPerMinute
        setFormatter(for: unit)

        XCTAssertEqual("mg/dL/min", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("1.0 mg/dL/min", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 1.0))!)
        XCTAssertEqual("5.2 mg/dL/min", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 5.2))!)
        XCTAssertEqual("10.1 mg/dL/min", formatter.string(from: LoopQuantity(unit: unit, doubleValue: 10.1))!)

    }

    func testAvoidLineBreaking() {
        setFormatter(for: .internationalUnit)
        formatter.avoidLineBreaking = true
        XCTAssertEqual("U", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10\(String.nonBreakingSpace)U", formatter.string(from: LoopQuantity(unit: .internationalUnit, doubleValue: 10))!)
        formatter.unitStyle = .short
        XCTAssertEqual("10\(String.wordJoiner)U", formatter.string(from: LoopQuantity(unit: .internationalUnit, doubleValue: 10))!)
        formatter.unitStyle = .long
        XCTAssertEqual("Units", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("10 Units", formatter.string(from: LoopQuantity(unit: .internationalUnit, doubleValue: 10))!)
        
        formatter.unitStyle = .medium
        setFormatter(for: .milligramsPerDeciliter)
        formatter.avoidLineBreaking = true
        XCTAssertEqual("mg\(String.wordJoiner)/\(String.wordJoiner)dL", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("60\(String.nonBreakingSpace)mg\(String.wordJoiner)/\(String.wordJoiner)dL", formatter.string(from: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 60))!)
        XCTAssertEqual("180\(String.nonBreakingSpace)mg\(String.wordJoiner)/\(String.wordJoiner)dL", formatter.string(from: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 180))!)
        formatter.unitStyle = .short
        XCTAssertEqual("mg\(String.wordJoiner)/\(String.wordJoiner)dL", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("60\(String.wordJoiner)mg\(String.wordJoiner)/\(String.wordJoiner)dL", formatter.string(from: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 60))!)
        XCTAssertEqual("180\(String.wordJoiner)mg\(String.wordJoiner)/\(String.wordJoiner)dL", formatter.string(from: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 180))!)
        formatter.unitStyle = .long
        XCTAssertEqual("milligrams per deciliter", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("180 milligrams per deciliter", formatter.string(from: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 180))!)
        XCTAssertEqual("0 milligrams per deciliter", formatter.string(from: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 0))!)
        XCTAssertEqual("1 milligrams per deciliter", formatter.string(from: LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 1))!)
        
        formatter.unitStyle = .medium
        setFormatter(for: .millimolesPerLiter)
        formatter.avoidLineBreaking = true
        XCTAssertEqual("mmol\(String.wordJoiner)/\(String.wordJoiner)L", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("6.0\(String.nonBreakingSpace)mmol\(String.wordJoiner)/\(String.wordJoiner)L", formatter.string(from: LoopQuantity(unit: .millimolesPerLiter, doubleValue: 6))!)
        XCTAssertEqual("7.8\(String.nonBreakingSpace)mmol\(String.wordJoiner)/\(String.wordJoiner)L", formatter.string(from: LoopQuantity(unit: .millimolesPerLiter, doubleValue: 7.84))!)
        XCTAssertEqual("12.0\(String.nonBreakingSpace)mmol\(String.wordJoiner)/\(String.wordJoiner)L", formatter.string(from: LoopQuantity(unit: .millimolesPerLiter, doubleValue: 12))!)
        formatter.unitStyle = .short
        XCTAssertEqual("mmol\(String.wordJoiner)/\(String.wordJoiner)L", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("6.0\(String.wordJoiner)mmol\(String.wordJoiner)/\(String.wordJoiner)L", formatter.string(from: LoopQuantity(unit: .millimolesPerLiter, doubleValue: 6))!)
        XCTAssertEqual("7.8\(String.wordJoiner)mmol\(String.wordJoiner)/\(String.wordJoiner)L", formatter.string(from: LoopQuantity(unit: .millimolesPerLiter, doubleValue: 7.8))!)
        formatter.unitStyle = .long
        XCTAssertEqual("millimoles per liter", formatter.localizedUnitStringWithPlurality())
        XCTAssertEqual("5.5 millimoles per liter", formatter.string(from: LoopQuantity(unit: .millimolesPerLiter, doubleValue: 5.5))!)
        XCTAssertEqual("0.0 millimoles per liter", formatter.string(from: LoopQuantity(unit: .millimolesPerLiter, doubleValue: 0))!)
        XCTAssertEqual("1.0 millimoles per liter", formatter.string(from: LoopQuantity(unit: .millimolesPerLiter, doubleValue: 1))!)
    }

    func testUnitRounding() {
        let value = 1.2345
        var unit: LoopUnit = .milligramsPerDeciliter
        XCTAssertEqual(unit.roundForPreferredDigits(value: value), 1)

        unit = .milligramsPerDeciliterPerInternationalUnit
        XCTAssertEqual(unit.roundForPreferredDigits(value: value), 1)

        unit = .milligramsPerDeciliterPerMinute
        XCTAssertEqual(unit.roundForPreferredDigits(value: value), 1.2)

        unit = .millimolesPerLiter
        XCTAssertEqual(unit.roundForPreferredDigits(value: value), 1.2)

        unit = .millimolesPerLiterPerInternationalUnit
        XCTAssertEqual(unit.roundForPreferredDigits(value: value), 1.2)

        unit = .millimolesPerLiterPerMinute
        XCTAssertEqual(unit.roundForPreferredDigits(value: value), 1.2)
    }

    func testQuantityRounding() {
        let value = 1.2345
        var unit: LoopUnit = .milligramsPerDeciliter
        XCTAssertEqual(LoopQuantity(unit: unit, doubleValue: value).doubleValue(for: unit, withRounding: true), 1)

        unit = .milligramsPerDeciliterPerInternationalUnit
        XCTAssertEqual(LoopQuantity(unit: unit, doubleValue: value).doubleValue(for: unit, withRounding: true), 1)

        unit = .milligramsPerDeciliterPerMinute
        XCTAssertEqual(LoopQuantity(unit: unit, doubleValue: value).doubleValue(for: unit, withRounding: true), 1.2)

        unit = .millimolesPerLiter
        XCTAssertEqual(LoopQuantity(unit: unit, doubleValue: value).doubleValue(for: unit, withRounding: true), 1.2)

        unit = .millimolesPerLiterPerInternationalUnit
        XCTAssertEqual(LoopQuantity(unit: unit, doubleValue: value).doubleValue(for: unit, withRounding: true), 1.2)

        unit = .millimolesPerLiterPerMinute
        XCTAssertEqual(LoopQuantity(unit: unit, doubleValue: value).doubleValue(for: unit, withRounding: true), 1.2)
    }
}
