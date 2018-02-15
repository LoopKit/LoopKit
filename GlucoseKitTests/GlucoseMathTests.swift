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
    public let startDate: Date
    public let quantity: HKQuantity
    public let isDisplayOnly: Bool
    public let provenanceIdentifier: String

    public init(startDate: Date, quantity: HKQuantity, isDisplayOnly: Bool, provenanceIdentifier: String?) {
        self.startDate = startDate
        self.quantity = quantity
        self.isDisplayOnly = isDisplayOnly
        self.provenanceIdentifier = provenanceIdentifier ?? "com.loopkit.LoopKitTests"
    }
}


class GlucoseMathTests: XCTestCase {

    func loadInputFixture(_ resourceName: String) -> [GlucoseFixtureValue] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseFixtureValue(
                startDate: dateFormatter.date(from: $0["date"] as! String)!,
                quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliter(), doubleValue: $0["amount"] as! Double),
                isDisplayOnly: ($0["display_only"] as? Bool) ?? false,
                provenanceIdentifier: $0["provenance_identifier"] as? String
            )
        }
    }

    func loadOutputFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }
    
    func testMomentumEffectForBouncingGlucose() {
        let input = loadInputFixture("momentum_effect_bouncing_glucose_input")
        let output = loadOutputFixture("momentum_effect_bouncing_glucose_output")

        let effects = input.linearMomentumEffect()
        let unit = HKUnit.milligramsPerDeciliter()

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForRisingGlucose() {
        let input = loadInputFixture("momentum_effect_rising_glucose_input")
        let output = loadOutputFixture("momentum_effect_rising_glucose_output")

        let effects = input.linearMomentumEffect()
        let unit = HKUnit.milligramsPerDeciliter()

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForFallingGlucose() {
        let input = loadInputFixture("momentum_effect_falling_glucose_input")
        let output = loadOutputFixture("momentum_effect_falling_glucose_output")

        let effects = input.linearMomentumEffect()
        let unit = HKUnit.milligramsPerDeciliter()

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForStableGlucose() {
        let input = loadInputFixture("momentum_effect_stable_glucose_input")
        let output = loadOutputFixture("momentum_effect_stable_glucose_output")

        let effects = input.linearMomentumEffect()
        let unit = HKUnit.milligramsPerDeciliter()

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForDuplicateGlucose() {
        let input = loadInputFixture("momentum_effect_duplicate_glucose_input")
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForEmptyGlucose() {
        let input = [GlucoseFixtureValue]()
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForSpacedOutGlucose() {
        let input = loadInputFixture("momentum_effect_incomplete_glucose_input")
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForTooFewGlucose() {
        let input = loadInputFixture("momentum_effect_bouncing_glucose_input")[0...1]
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForDisplayOnlyGlucose() {
        let input = loadInputFixture("momentum_effect_display_only_glucose_input")
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

    func testMomentumEffectForMixedProvenanceGlucose() {
        let input = loadInputFixture("momentum_effect_mixed_provenance_glucose_input")
        let effects = input.linearMomentumEffect()

        XCTAssertEqual(0, effects.count)
    }

}
