//
//  LoopMathTests.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
import HealthKit
@testable import GlucoseKit
@testable import LoopKit


typealias RecentGlucoseValue = PredictedGlucoseValue


class LoopMathTests: XCTestCase {

    func loadGlucoseEffectFixture(resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = NSDateFormatter.ISO8601LocalTimeDateFormatter()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.dateFromString($0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(fromString: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func loadSampleValueFixture(resourceName: String) -> [(startDate: NSDate, quantity: HKQuantity)] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = NSDateFormatter.ISO8601StrictDateFormatter()

        return fixture.map {
            (dateFormatter.dateFromString($0["startDate"] as! String)!, HKQuantity(unit: HKUnit(fromString: $0["unit"] as! String), doubleValue: $0["value"] as! Double))
        }
    }

    func loadGlucoseHistoryFixture(resourceName: String) -> RecentGlucoseValue {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = NSDateFormatter.ISO8601LocalTimeDateFormatter()

        return fixture.map {
            return RecentGlucoseValue(startDate: dateFormatter.dateFromString($0["display_time"] as! String)!, quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliterUnit(), doubleValue:$0["glucose"] as! Double))
        }.first!
    }

    func loadGlucoseValueFixture(resourceName: String) -> [PredictedGlucoseValue] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = NSDateFormatter.ISO8601LocalTimeDateFormatter()

        return fixture.map {
            return PredictedGlucoseValue(startDate: dateFormatter.dateFromString($0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(fromString: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    lazy var carbEffect: [GlucoseEffect] = {
        return self.loadGlucoseEffectFixture("glucose_from_effects_carb_effect_input")
    }()

    lazy var insulinEffect: [GlucoseEffect] = {
        return self.loadGlucoseEffectFixture("glucose_from_effects_insulin_effect_input")
    }()

    func testPredictGlucoseNoMomentum() {
        let glucose = loadGlucoseHistoryFixture("glucose_from_effects_glucose_input")

        let expected = loadGlucoseValueFixture("glucose_from_effects_no_momentum_output")

        let calculated = LoopMath.predictGlucose(glucose, effects: carbEffect, insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), calculated.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), accuracy: pow(10, -11))
        }
    }

    func testPredictGlucoseFlatMomentum() {
        let glucose = loadGlucoseHistoryFixture("glucose_from_effects_momentum_flat_glucose_input")
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_flat_input")
        let expected = loadGlucoseValueFixture("glucose_from_effects_momentum_flat_output")

        let calculated = LoopMath.predictGlucose(glucose, momentum: momentum, effects: carbEffect, insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), calculated.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), accuracy: pow(10, -11))
        }
    }

    func testPredictGlucoseUpMomentum() {
        let glucose = loadGlucoseHistoryFixture("glucose_from_effects_glucose_input")
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_up_input")
        let expected = loadGlucoseValueFixture("glucose_from_effects_momentum_up_output")

        let calculated = LoopMath.predictGlucose(glucose, momentum: momentum, effects: carbEffect, insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), calculated.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), accuracy: pow(10, -11))
        }
    }

    func testPredictGlucoseDownMomentum() {
        let glucose = loadGlucoseHistoryFixture("glucose_from_effects_glucose_input")
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_down_input")
        let expected = loadGlucoseValueFixture("glucose_from_effects_momentum_down_output")

        let calculated = LoopMath.predictGlucose(glucose, momentum: momentum, effects: carbEffect, insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), calculated.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), accuracy: pow(10, -11))
        }
    }

    func testPredictGlucoseBlendMomentum() {
        let glucose = loadGlucoseHistoryFixture("glucose_from_effects_momentum_blend_glucose_input")
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_blend_momentum_input")
        let insulinEffect = loadGlucoseEffectFixture("glucose_from_effects_momentum_blend_insulin_effect_input")
        let expected = loadGlucoseValueFixture("glucose_from_effects_momentum_blend_output")

        let calculated = LoopMath.predictGlucose(glucose, momentum: momentum, effects: insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), calculated.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), accuracy: pow(10, -11))
        }
    }

    func testPredictGlucoseStartingEffectsNonZero() {
        let glucose = loadSampleValueFixture("glucose_from_effects_non_zero_glucose_input").first!
        let insulinEffect = loadSampleValueFixture("glucose_from_effects_non_zero_insulin_input").map {
            GlucoseEffect(startDate: $0.startDate, quantity: $0.quantity)
        }
        let carbEffect = loadSampleValueFixture("glucose_from_effects_non_zero_carb_input").map {
            GlucoseEffect(startDate: $0.startDate, quantity: $0.quantity)
        }
        let expected = loadSampleValueFixture("glucose_from_effects_non_zero_output").map {
            GlucoseEffect(startDate: $0.startDate, quantity: $0.quantity)
        }

        let calculated = LoopMath.predictGlucose(RecentGlucoseValue(startDate: glucose.startDate, quantity: glucose.quantity),
            effects: insulinEffect, carbEffect
        )

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), calculated.quantity.doubleValueForUnit(HKUnit.milligramsPerDeciliterUnit()), accuracy: pow(10, -11))
        }
    }

    func testDecayEffect() {
        let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
        let glucoseDate = calendar.dateWithEra(1, year: 2016, month: 2, day: 1, hour: 10, minute: 13, second: 20, nanosecond: 0)!
        let type = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
        let unit = HKUnit.milligramsPerDeciliterUnit()
        let glucose = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 100), startDate: glucoseDate, endDate: glucoseDate)

        var startingEffect = HKQuantity(unit: unit.unitDividedByUnit(HKUnit.minuteUnit()), doubleValue: 2)

        var effects = LoopMath.decayEffect(from: glucose, atRate: startingEffect, for: NSTimeInterval(30 * 60))

        XCTAssertEqual([100, 110, 118, 124, 128, 130, 130], effects.map { $0.quantity.doubleValueForUnit(unit) })

        let startDate = effects.first!.startDate
        XCTAssertEqual([0, 5, 10, 15, 20, 25, 30], effects.map { $0.startDate.timeIntervalSinceDate(startDate).minutes })

        startingEffect = HKQuantity(unit: unit.unitDividedByUnit(HKUnit.minuteUnit()), doubleValue: -0.5)
        effects = LoopMath.decayEffect(from: glucose, atRate: startingEffect, for: NSTimeInterval(30 * 60))
        XCTAssertEqual([100, 97.5, 95.5, 94, 93, 92.5, 92.5], effects.map { $0.quantity.doubleValueForUnit(unit) })
    }

    func testDecayEffectWithEvenGlucose() {
        let calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierGregorian)!
        let glucoseDate = calendar.dateWithEra(1, year: 2016, month: 2, day: 1, hour: 10, minute: 15, second: 0, nanosecond: 0)!
        let type = HKQuantityType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
        let unit = HKUnit.milligramsPerDeciliterUnit()
        let glucose = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 100), startDate: glucoseDate, endDate: glucoseDate)

        var startingEffect = HKQuantity(unit: unit.unitDividedByUnit(HKUnit.minuteUnit()), doubleValue: 2)

        var effects = LoopMath.decayEffect(from: glucose, atRate: startingEffect, for: NSTimeInterval(30 * 60))

        XCTAssertEqual([100, 110, 118, 124, 128, 130], effects.map { $0.quantity.doubleValueForUnit(unit) })

        let startDate = effects.first!.startDate
        XCTAssertEqual([0, 5, 10, 15, 20, 25], effects.map { $0.startDate.timeIntervalSinceDate(startDate).minutes })

        startingEffect = HKQuantity(unit: unit.unitDividedByUnit(HKUnit.minuteUnit()), doubleValue: -0.5)
        effects = LoopMath.decayEffect(from: glucose, atRate: startingEffect, for: NSTimeInterval(30 * 60))
        XCTAssertEqual([100, 97.5, 95.5, 94, 93, 92.5], effects.map { $0.quantity.doubleValueForUnit(unit) })
    }
}
