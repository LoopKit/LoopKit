//
//  LoopMathTests.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/2/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit


typealias RecentGlucoseValue = PredictedGlucoseValue


class LoopMathTests: XCTestCase {

    func loadGlucoseEffectFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func loadSampleValueFixture(_ resourceName: String) -> [(startDate: Date, quantity: HKQuantity)] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter()

        return fixture.map {
            (dateFormatter.date(from: $0["startDate"] as! String)!, HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue: $0["value"] as! Double))
        }
    }

    func loadGlucoseHistoryFixture(_ resourceName: String) -> RecentGlucoseValue {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return RecentGlucoseValue(startDate: dateFormatter.date(from: $0["display_time"] as! String)!, quantity: HKQuantity(unit: HKUnit.milligramsPerDeciliter, doubleValue:$0["glucose"] as! Double))
        }.first!
    }

    func loadGlucoseValueFixture(_ resourceName: String) -> [PredictedGlucoseValue] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return PredictedGlucoseValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
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

        let calculated = LoopMath.predictGlucose(startingAt: glucose, effects: carbEffect, insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testPredictGlucoseFlatMomentum() {
        let glucose = loadGlucoseHistoryFixture("glucose_from_effects_momentum_flat_glucose_input")
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_flat_input")
        let expected = loadGlucoseValueFixture("glucose_from_effects_momentum_flat_output")

        let calculated = LoopMath.predictGlucose(startingAt: glucose, momentum: momentum, effects: carbEffect, insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testPredictGlucoseUpMomentum() {
        let glucose = loadGlucoseHistoryFixture("glucose_from_effects_glucose_input")
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_up_input")
        let expected = loadGlucoseValueFixture("glucose_from_effects_momentum_up_output")

        let calculated = LoopMath.predictGlucose(startingAt: glucose, momentum: momentum, effects: carbEffect, insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testPredictGlucoseDownMomentum() {
        let glucose = loadGlucoseHistoryFixture("glucose_from_effects_glucose_input")
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_down_input")
        let expected = loadGlucoseValueFixture("glucose_from_effects_momentum_down_output")

        let calculated = LoopMath.predictGlucose(startingAt: glucose, momentum: momentum, effects: carbEffect, insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testPredictGlucoseBlendMomentum() {
        let glucose = loadGlucoseHistoryFixture("glucose_from_effects_momentum_blend_glucose_input")
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_blend_momentum_input")
        let insulinEffect = loadGlucoseEffectFixture("glucose_from_effects_momentum_blend_insulin_effect_input")
        let expected = loadGlucoseValueFixture("glucose_from_effects_momentum_blend_output")

        let calculated = LoopMath.predictGlucose(startingAt: glucose, momentum: momentum, effects: insulinEffect)

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
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

        let calculated = LoopMath.predictGlucose(startingAt: RecentGlucoseValue(startDate: glucose.startDate, quantity: glucose.quantity),
            effects: insulinEffect, carbEffect
        )

        XCTAssertEqual(expected.count, calculated.count)

        for (expected, calculated) in zip(expected, calculated) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testDecayEffect() {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let glucoseDate = calendar.date(from: DateComponents(year: 2016, month: 2, day: 1, hour: 10, minute: 13, second: 20))!
        let type = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        let unit = HKUnit.milligramsPerDeciliter
        let glucose = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 100), start: glucoseDate, end: glucoseDate)

        var startingEffect = HKQuantity(unit: unit.unitDivided(by: HKUnit.minute()), doubleValue: 2)

        var effects = glucose.decayEffect(atRate: startingEffect, for: .minutes(30))

        XCTAssertEqual([100, 110, 118, 124, 128, 130, 130], effects.map { $0.quantity.doubleValue(for: unit) })

        let startDate = effects.first!.startDate
        XCTAssertEqual([0, 5, 10, 15, 20, 25, 30], effects.map { $0.startDate.timeIntervalSince(startDate).minutes })

        startingEffect = HKQuantity(unit: unit.unitDivided(by: HKUnit.minute()), doubleValue: -0.5)
        effects = glucose.decayEffect(atRate: startingEffect, for: .minutes(30))
        XCTAssertEqual([100, 97.5, 95.5, 94, 93, 92.5, 92.5], effects.map { $0.quantity.doubleValue(for: unit) })
    }

    func testDecayEffectWithEvenGlucose() {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let glucoseDate = calendar.date(from: DateComponents(year: 2016, month: 2, day: 1, hour: 10, minute: 15, second: 0))!
        let type = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        let unit = HKUnit.milligramsPerDeciliter
        let glucose = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: 100), start: glucoseDate, end: glucoseDate)

        var startingEffect = HKQuantity(unit: unit.unitDivided(by: HKUnit.minute()), doubleValue: 2)

        var effects = glucose.decayEffect(atRate: startingEffect, for: .minutes(30))

        XCTAssertEqual([100, 110, 118, 124, 128, 130], effects.map { $0.quantity.doubleValue(for: unit) })

        let startDate = effects.first!.startDate
        XCTAssertEqual([0, 5, 10, 15, 20, 25], effects.map { $0.startDate.timeIntervalSince(startDate).minutes })

        startingEffect = HKQuantity(unit: unit.unitDivided(by: HKUnit.minute()), doubleValue: -0.5)
        effects = glucose.decayEffect(atRate: startingEffect, for: .minutes(30))
        XCTAssertEqual([100, 97.5, 95.5, 94, 93, 92.5], effects.map { $0.quantity.doubleValue(for: unit) })
    }
}
