//
//  GlucoseMathTests.swift
//  GlucoseKitTests
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
@testable import LoopKit
import HealthKit


public struct GlucoseFixtureValue: GlucoseSampleValue {
    public let startDate: Date
    public let quantity: HKQuantity
    public let isDisplayOnly: Bool
    public let wasUserEntered: Bool
    public let provenanceIdentifier: String

    public init(startDate: Date, quantity: HKQuantity, isDisplayOnly: Bool, wasUserEntered: Bool, provenanceIdentifier: String?) {
        self.startDate = startDate
        self.quantity = quantity
        self.isDisplayOnly = isDisplayOnly
        self.wasUserEntered = wasUserEntered
        self.provenanceIdentifier = provenanceIdentifier ?? "com.loopkit.LoopKitTests"
    }
}


extension GlucoseFixtureValue: Comparable {
    public static func <(lhs: GlucoseFixtureValue, rhs: GlucoseFixtureValue) -> Bool {
        return lhs.startDate < rhs.startDate
    }

    public static func ==(lhs: GlucoseFixtureValue, rhs: GlucoseFixtureValue) -> Bool {
        return lhs.startDate == rhs.startDate &&
               lhs.quantity == rhs.quantity &&
               lhs.isDisplayOnly == rhs.isDisplayOnly &&
               lhs.wasUserEntered == rhs.wasUserEntered &&
               lhs.provenanceIdentifier == rhs.provenanceIdentifier
    }
}


class GlucoseMathTests: XCTestCase {

    private func printFixture(_ effectVelocity: [GlucoseEffectVelocity]) {
        let formatter = ISO8601DateFormatter.localTimeDate()
        let unit = HKUnit.milligramsPerDeciliter.unitDivided(by: .minute())

        print("\n\n")
        print(String(data: try! JSONSerialization.data(
            withJSONObject: effectVelocity.map({ (value) -> [String: Any] in
                return [
                    "startDate": formatter.string(from: value.startDate),
                    "endDate": formatter.string(from: value.endDate),
                    "value": value.quantity.doubleValue(for: unit),
                    "unit": unit.unitString
                ]
            }),
            options: .prettyPrinted), encoding: .utf8)!)
        print("\n\n")
    }

    func loadInputFixture(_ resourceName: String) -> [GlucoseFixtureValue] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseFixtureValue(
                startDate: dateFormatter.date(from: $0["date"] as! String)!,
                quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliter, doubleValue: $0["amount"] as! Double),
                isDisplayOnly: ($0["display_only"] as? Bool) ?? false,
                wasUserEntered: ($0["user_entered"] as? Bool) ?? false,
                provenanceIdentifier: $0["provenance_identifier"] as? String
            )
        }
    }

    func loadOutputFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue: $0["amount"] as! Double))
        }
    }

    func loadEffectVelocityFixture(_ resourceName: String) -> [GlucoseEffectVelocity] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffectVelocity(startDate: dateFormatter.date(from: $0["startDate"] as! String)!, endDate: dateFormatter.date(from: $0["endDate"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["value"] as! Double))
        }
    }
    
    func testMomentumEffectForBouncingGlucose() {
        let input = loadInputFixture("momentum_effect_bouncing_glucose_input")
        let output = loadOutputFixture("momentum_effect_bouncing_glucose_output")

        let effects = input.linearMomentumEffect()
        let unit = HKUnit.milligramsPerDeciliter

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
        let unit = HKUnit.milligramsPerDeciliter

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForRisingGlucoseDoubles() {
        let input = loadInputFixture("momentum_effect_rising_glucose_double_entries_input")
        let output = loadOutputFixture("momentum_effect_rising_glucose_output")

        let effects = input.linearMomentumEffect()
        let unit = HKUnit.milligramsPerDeciliter

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
        let unit = HKUnit.milligramsPerDeciliter

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testMomentumEffectForFallingGlucoseDuplicates() {
        var input = loadInputFixture("momentum_effect_falling_glucose_input")
        let output = loadOutputFixture("momentum_effect_falling_glucose_output")
        input.append(contentsOf: input)
        input.sort(by: <)

        let effects = input.linearMomentumEffect()
        let unit = HKUnit.milligramsPerDeciliter

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
        let unit = HKUnit.milligramsPerDeciliter

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

    func testCounteractionEffectsForFallingGlucose() {
        let input = loadInputFixture("counteraction_effect_falling_glucose_input")
        let insulinEffect = loadOutputFixture("counteraction_effect_falling_glucose_insulin")
        let output = loadEffectVelocityFixture("counteraction_effect_falling_glucose_output")

        let effects = input.counteractionEffects(to: insulinEffect)
        let unit = HKUnit.milligramsPerDeciliter.unitDivided(by: .minute())

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testCounteractionEffectsForFallingGlucoseDuplicates() {
        var input = loadInputFixture("counteraction_effect_falling_glucose_input")
        input.append(contentsOf: input)
        input.sort(by: <)
        let insulinEffect = loadOutputFixture("counteraction_effect_falling_glucose_insulin")
        let output = loadEffectVelocityFixture("counteraction_effect_falling_glucose_output")

        let effects = input.counteractionEffects(to: insulinEffect)
        let unit = HKUnit.milligramsPerDeciliter.unitDivided(by: .minute())

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testCounteractionEffectsForFallingGlucoseAlmostDuplicates() {
        let input = loadInputFixture("counteraction_effect_falling_glucose_almost_duplicates_input")
        let insulinEffect = loadOutputFixture("counteraction_effect_falling_glucose_insulin")
        let output = loadEffectVelocityFixture("counteraction_effect_falling_glucose_almost_duplicates_output")

        let effects = input.counteractionEffects(to: insulinEffect)
        let unit = HKUnit.milligramsPerDeciliter.unitDivided(by: .minute())

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testCounteractionEffectsForNoGlucose() {
        let input = [GlucoseFixtureValue]()
        let insulinEffect = loadOutputFixture("counteraction_effect_falling_glucose_insulin")
        let output = [GlucoseEffectVelocity]()

        let effects = input.counteractionEffects(to: insulinEffect)

        XCTAssertEqual(output.count, effects.count)
    }
    
    func testMomentumEffectWithVelocityLimit() {
        let input = loadInputFixture("momentum_effect_impossible_rising_glucose_input")
        let output = loadOutputFixture("momentum_effect_impossible_rising_glucose_output")

        let effects = input.linearMomentumEffect()
        let unit = HKUnit.milligramsPerDeciliter

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: unit), calculated.quantity.doubleValue(for: unit), accuracy: Double(Float.ulpOfOne))
        }
    }
}
