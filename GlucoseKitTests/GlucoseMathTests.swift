//
//  GlucoseMathTests.swift
//  GlucoseKitTests
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
@testable import GlucoseKit
@testable import LoopKit
import HealthKit


public struct GlucoseFixtureValue: GlucoseSampleValue {
    public let startDate: NSDate
    public let quantity: HKQuantity
    public let displayOnly: Bool

    public init(startDate: NSDate, quantity: HKQuantity, displayOnly: Bool) {
        self.startDate = startDate
        self.quantity = quantity
        self.displayOnly = displayOnly
    }
}


class GlucoseMathTests: XCTestCase {

    func loadInputFixture(resourceName: String) -> [GlucoseFixtureValue] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = NSDateFormatter.ISO8601LocalTimeDateFormatter()

        return fixture.map {
            return GlucoseFixtureValue(
                startDate: dateFormatter.dateFromString($0["date"] as! String)!,
                quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliterUnit(), doubleValue: $0["amount"] as! Double),
                displayOnly: ($0["display_only"] as? Bool) ?? false
            )
        }
    }

    func loadOutputFixture(resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = NSDateFormatter.ISO8601LocalTimeDateFormatter()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.dateFromString($0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(fromString: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }
    
    func testMomentumEffectForBouncingGlucose() {
        let input = loadInputFixture("momentum_effect_bouncing_glucose_input")
        let output = loadOutputFixture("momentum_effect_bouncing_glucose_output")

        let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(input)
        let unit = HKUnit.milligramsPerDeciliterUnit()

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(unit), calculated.quantity.doubleValueForUnit(unit), accuracy: pow(10, -14))
        }
    }

    func testMomentumEffectForRisingGlucose() {
        let input = loadInputFixture("momentum_effect_rising_glucose_input")
        let output = loadOutputFixture("momentum_effect_rising_glucose_output")

        let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(input)
        let unit = HKUnit.milligramsPerDeciliterUnit()

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(unit), calculated.quantity.doubleValueForUnit(unit), accuracy: pow(10, -14))
        }
    }

    func testMomentumEffectForFallingGlucose() {
        let input = loadInputFixture("momentum_effect_falling_glucose_input")
        let output = loadOutputFixture("momentum_effect_falling_glucose_output")

        let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(input)
        let unit = HKUnit.milligramsPerDeciliterUnit()

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(unit), calculated.quantity.doubleValueForUnit(unit), accuracy: pow(10, -14))
        }
    }

    func testMomentumEffectForStableGlucose() {
        let input = loadInputFixture("momentum_effect_stable_glucose_input")
        let output = loadOutputFixture("momentum_effect_stable_glucose_output")

        let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(input)
        let unit = HKUnit.milligramsPerDeciliterUnit()

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(unit), calculated.quantity.doubleValueForUnit(unit), accuracy: pow(10, -14))
        }
    }

    func testMomentumEffectForEmptyGlucose() {
        let input = [GlucoseFixtureValue]()
        let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(input)

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForSpacedOutGlucose() {
        let input = loadInputFixture("momentum_effect_incomplete_glucose_input")
        let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(input)

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForTooFewGlucose() {
        let input = loadInputFixture("momentum_effect_bouncing_glucose_input")[0...1]
        let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(input)

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForDisplayOnlyGlucose() {
        let input = loadInputFixture("momentum_effect_display_only_glucose_input")
        let effects = GlucoseMath.linearMomentumEffectForGlucoseEntries(input)

        XCTAssertEqual(0, effects.count)
    }
}
