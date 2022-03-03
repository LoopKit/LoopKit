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

    func loadGlucoseEffectFixture(_ resourceName: String, formatter: ISO8601DateFormatter) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)

        return fixture.map {
            return GlucoseEffect(startDate: formatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func loadGlucoseEffectFixture(_ resourceName: String, formatter: DateFormatter) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)

        return fixture.map {
            return GlucoseEffect(startDate: formatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue: $0["value"] as! Double))
        }
    }

    private func printFixture(_ glucoseEffect: [GlucoseEffect]) {
        let unit = HKUnit.milligramsPerDeciliter

        print("\n\n")
        print(String(data: try! JSONSerialization.data(
            withJSONObject: glucoseEffect.map({ (value) -> [String: Any] in
                return [
                    "date": String(describing: value.startDate),
                    "value": value.quantity.doubleValue(for: unit),
                    "unit": unit.unitString
                ]
            }),
            options: .prettyPrinted), encoding: .utf8)!)
        print("\n\n")
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
        return self.loadGlucoseEffectFixture("glucose_from_effects_carb_effect_input", formatter: ISO8601DateFormatter.localTimeDate())
    }()

    lazy var insulinEffect: [GlucoseEffect] = {
        return self.loadGlucoseEffectFixture("glucose_from_effects_insulin_effect_input", formatter: ISO8601DateFormatter.localTimeDate())
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
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_flat_input", formatter: ISO8601DateFormatter.localTimeDate())
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
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_up_input", formatter: ISO8601DateFormatter.localTimeDate())
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
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_down_input", formatter: ISO8601DateFormatter.localTimeDate())
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
        let momentum = loadGlucoseEffectFixture("glucose_from_effects_momentum_blend_momentum_input", formatter: ISO8601DateFormatter.localTimeDate())
        let insulinEffect = loadGlucoseEffectFixture("glucose_from_effects_momentum_blend_insulin_effect_input", formatter: ISO8601DateFormatter.localTimeDate())
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

    func testSubtractingCarbEffectFromICEWithGaps() {
        let perMinute = HKUnit.milligramsPerDeciliter.unitDivided(by: .minute())
        let mgdl = HKUnit.milligramsPerDeciliter

        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        let insulinCounteractionEffects = [
            GlucoseEffectVelocity(startDate: f("2018-08-16 01:03:43 +0000"), endDate: f("2018-08-16 01:08:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -0.0063630385383878375)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 01:08:43 +0000"), endDate: f("2018-08-16 01:13:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.3798225216554212)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 01:13:44 +0000"), endDate: f("2018-08-16 01:18:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.5726970790754702)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 01:18:44 +0000"), endDate: f("2018-08-16 01:23:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.7936837738660198)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 01:23:44 +0000"), endDate: f("2018-08-16 01:28:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 1.2143200509835315)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 01:28:43 +0000"), endDate: f("2018-08-16 02:03:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 1.214239367352738)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 02:03:43 +0000"), endDate: f("2018-08-16 03:13:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.64964443000756)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:13:44 +0000"), endDate: f("2018-08-16 03:18:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.40933503856266396)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:18:44 +0000"), endDate: f("2018-08-16 03:23:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.5994115966821696)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:23:43 +0000"), endDate: f("2018-08-16 03:28:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.640336708627245)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:28:44 +0000"), endDate: f("2018-08-16 03:33:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 1.5109774027636143)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:33:43 +0000"), endDate: f("2018-08-16 03:38:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -1.6358198764701966)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:38:43 +0000"), endDate: f("2018-08-16 03:43:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.4187533857556986)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:43:44 +0000"), endDate: f("2018-08-16 03:48:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -1.136005257968153)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:48:43 +0000"), endDate: f("2018-08-16 03:53:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -0.29635521996668046)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:53:44 +0000"), endDate: f("2018-08-16 03:58:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -1.070285990192832)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 03:58:43 +0000"), endDate: f("2018-08-16 04:03:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -0.25025410282677996)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 04:03:43 +0000"), endDate: f("2018-08-16 04:08:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.5598990284715561)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 04:08:43 +0000"), endDate: f("2018-08-16 04:13:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 1.9616378142801167)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 04:13:44 +0000"), endDate: f("2018-08-16 04:18:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 1.7593854114682483)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 04:18:43 +0000"), endDate: f("2018-08-16 04:23:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.5467358931981837)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 04:23:44 +0000"), endDate: f("2018-08-16 04:28:44 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.9335047268082058)),
            GlucoseEffectVelocity(startDate: f("2018-08-16 04:28:44 +0000"), endDate: f("2018-08-16 04:33:43 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -0.2823274349191665)),
        ]

        let carbEffects = [
            GlucoseEffect(startDate: f("2018-08-16 01:00:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 69.38642455065255)),
            GlucoseEffect(startDate: f("2018-08-16 01:05:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 69.38642455065255)),
            GlucoseEffect(startDate: f("2018-08-16 01:10:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 72.18741125500856)),
            GlucoseEffect(startDate: f("2018-08-16 01:15:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 82.00120184863087)),
            GlucoseEffect(startDate: f("2018-08-16 01:20:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 90.79285286260895)),
            GlucoseEffect(startDate: f("2018-08-16 01:25:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 93.5316456300059)),
            GlucoseEffect(startDate: f("2018-08-16 01:30:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 98.19664696604428)),
            GlucoseEffect(startDate: f("2018-08-16 01:35:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 98.5800323225078)),
            GlucoseEffect(startDate: f("2018-08-16 01:40:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 100.09237800152016)),
            GlucoseEffect(startDate: f("2018-08-16 01:45:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 101.60472368053252)),
            GlucoseEffect(startDate: f("2018-08-16 01:50:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 103.11706935954487)),
            GlucoseEffect(startDate: f("2018-08-16 01:55:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 104.6294150385572)),
            GlucoseEffect(startDate: f("2018-08-16 02:00:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 129.38642455065255)),
            GlucoseEffect(startDate: f("2018-08-16 02:05:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 129.38642455065255)),
            GlucoseEffect(startDate: f("2018-08-16 02:10:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 132.18741125500856)),
            GlucoseEffect(startDate: f("2018-08-16 02:15:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 142.00120184863087)),
            GlucoseEffect(startDate: f("2018-08-16 02:20:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 150.79285286260895)),
            GlucoseEffect(startDate: f("2018-08-16 02:25:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 153.5316456300059)),
            GlucoseEffect(startDate: f("2018-08-16 02:30:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 158.19664696604428)),
            GlucoseEffect(startDate: f("2018-08-16 02:35:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 158.5800323225078)),
            GlucoseEffect(startDate: f("2018-08-16 02:40:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 160.09237800152016)),
            GlucoseEffect(startDate: f("2018-08-16 02:45:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 161.60472368053252)),
            GlucoseEffect(startDate: f("2018-08-16 02:50:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 163.11706935954487)),
            GlucoseEffect(startDate: f("2018-08-16 02:55:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 164.6294150385572)),
            GlucoseEffect(startDate: f("2018-08-16 03:00:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 166.14176071756955)),
            GlucoseEffect(startDate: f("2018-08-16 03:05:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 167.65410639658188)),
            GlucoseEffect(startDate: f("2018-08-16 03:10:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 169.16645207559424)),
            GlucoseEffect(startDate: f("2018-08-16 03:15:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 170.6787977546066)),
            GlucoseEffect(startDate: f("2018-08-16 03:20:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 172.19114343361895)),
            GlucoseEffect(startDate: f("2018-08-16 03:25:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 173.70348911263127)),
            GlucoseEffect(startDate: f("2018-08-16 03:30:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 175.21583479164363)),
            GlucoseEffect(startDate: f("2018-08-16 03:35:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 176.72818047065596)),
            GlucoseEffect(startDate: f("2018-08-16 03:40:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 178.2405261496683)),
            GlucoseEffect(startDate: f("2018-08-16 03:45:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 179.75287182868067)),
            GlucoseEffect(startDate: f("2018-08-16 03:50:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 181.26521750769302)),
            GlucoseEffect(startDate: f("2018-08-16 03:55:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 182.77756318670535)),
            GlucoseEffect(startDate: f("2018-08-16 04:00:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 189.38642455065255)),
            GlucoseEffect(startDate: f("2018-08-16 04:05:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 189.38642455065255)),
            GlucoseEffect(startDate: f("2018-08-16 04:10:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 192.18741125500856)),
            GlucoseEffect(startDate: f("2018-08-16 04:15:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 202.00120184863087)),
            GlucoseEffect(startDate: f("2018-08-16 04:20:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 210.79285286260895)),
            GlucoseEffect(startDate: f("2018-08-16 04:25:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 213.5316456300059)),
            GlucoseEffect(startDate: f("2018-08-16 04:30:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 218.19664696604428)),
            GlucoseEffect(startDate: f("2018-08-16 04:35:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 218.5800323225078)),
            GlucoseEffect(startDate: f("2018-08-16 04:40:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 220.09237800152016)),
            GlucoseEffect(startDate: f("2018-08-16 04:45:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 221.60472368053252)),
            GlucoseEffect(startDate: f("2018-08-16 04:50:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 223.11706935954487)),
            GlucoseEffect(startDate: f("2018-08-16 04:55:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 224.6294150385572)),
            GlucoseEffect(startDate: f("2018-08-16 05:00:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 226.14176071756955)),
            GlucoseEffect(startDate: f("2018-08-16 05:05:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 227.65410639658188)),
            GlucoseEffect(startDate: f("2018-08-16 05:10:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 229.16645207559424)),
            GlucoseEffect(startDate: f("2018-08-16 05:15:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 230.6787977546066)),
            GlucoseEffect(startDate: f("2018-08-16 05:20:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 232.19114343361895)),
            GlucoseEffect(startDate: f("2018-08-16 05:25:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 233.70348911263127)),
            GlucoseEffect(startDate: f("2018-08-16 05:30:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 235.21583479164363)),
            GlucoseEffect(startDate: f("2018-08-16 05:35:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 236.72818047065596)),
            GlucoseEffect(startDate: f("2018-08-16 05:40:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 238.2405261496683)),
            GlucoseEffect(startDate: f("2018-08-16 05:45:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 239.75287182868067)),
            GlucoseEffect(startDate: f("2018-08-16 05:50:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 241.26521750769302)),
            GlucoseEffect(startDate: f("2018-08-16 05:55:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 242.77756318670535)),
            GlucoseEffect(startDate: f("2018-08-16 06:00:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 244.28990886571768)),
            GlucoseEffect(startDate: f("2018-08-16 06:05:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 245.80225454473003)),
            GlucoseEffect(startDate: f("2018-08-16 06:10:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 247.3146002237424)),
            GlucoseEffect(startDate: f("2018-08-16 06:15:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 248.82694590275474)),
            GlucoseEffect(startDate: f("2018-08-16 06:20:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 250.33929158176707)),
            GlucoseEffect(startDate: f("2018-08-16 06:25:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 251.85163726077943)),
            GlucoseEffect(startDate: f("2018-08-16 06:30:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 253.16666666666669)),
            GlucoseEffect(startDate: f("2018-08-16 06:35:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 253.16666666666669)),
            GlucoseEffect(startDate: f("2018-08-16 06:40:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 253.16666666666669)),
        ]

        let calculated = insulinCounteractionEffects.subtracting(carbEffects, withUniformInterval: .minutes(5))

        let expected = loadGlucoseEffectFixture("ice_minus_carb_effect_with_gaps_output", formatter: DateFormatter.descriptionFormatter)

        XCTAssertEqual(expected, calculated)
    }

    func testSubtractingFlatCarbEffectFromICE() {
        let perMinute = HKUnit.milligramsPerDeciliter.unitDivided(by: .minute())
        let mgdl = HKUnit.milligramsPerDeciliter

        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        let insulinCounteractionEffects = [
            GlucoseEffectVelocity(startDate: f("2018-08-26 00:23:27 +0000"), endDate: f("2018-08-26 00:28:28 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.3711911901542791)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 00:28:28 +0000"), endDate: f("2018-08-26 00:33:27 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -0.4382943196158106)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 00:33:27 +0000"), endDate: f("2018-08-26 00:38:27 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -0.24797050925219474)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 00:38:27 +0000"), endDate: f("2018-08-26 00:43:28 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: -0.05800368381887202)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 00:43:28 +0000"), endDate: f("2018-08-26 00:48:28 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.7303422936657988)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 00:48:28 +0000"), endDate: f("2018-08-26 00:53:28 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.7166291304729353)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 00:53:28 +0000"), endDate: f("2018-08-26 00:58:28 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.2962279320324577)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 00:58:28 +0000"), endDate: f("2018-08-26 01:03:27 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.2730196016663657)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 01:03:27 +0000"), endDate: f("2018-08-26 01:08:28 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.44605609358758713)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 01:08:28 +0000"), endDate: f("2018-08-26 01:13:28 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.42131971635266463)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 01:13:28 +0000"), endDate: f("2018-08-26 01:18:27 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.9948293689475411)),
            GlucoseEffectVelocity(startDate: f("2018-08-26 01:18:27 +0000"), endDate: f("2018-08-26 01:23:28 +0000"), quantity: HKQuantity(unit: perMinute, doubleValue: 0.9652238210644638)),
        ]

        let carbEffects = [
            GlucoseEffect(startDate: f("2018-08-26 00:45:00 +0000"), quantity: HKQuantity(unit: mgdl, doubleValue: 385.8235294117647))
        ]

        let calculated = insulinCounteractionEffects.subtracting(carbEffects, withUniformInterval: .minutes(5))

        let expected = loadGlucoseEffectFixture("ice_minus_flat_carb_effect_output", formatter: DateFormatter.descriptionFormatter)

        XCTAssertEqual(expected, calculated)
    }

    func testCombinedSumsWithGaps() {
        let input = loadGlucoseEffectFixture("ice_minus_carb_effect_with_gaps_output", formatter: DateFormatter.descriptionFormatter)
        let unit = HKUnit.milligramsPerDeciliter

        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        let expected = [
            GlucoseChange(startDate: f("2018-08-16 01:13:44 +0000"), endDate: f("2018-08-16 01:13:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -7.914677985345208)),
            GlucoseChange(startDate: f("2018-08-16 01:13:44 +0000"), endDate: f("2018-08-16 01:18:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -13.84284360394594)),
            GlucoseChange(startDate: f("2018-08-16 01:13:44 +0000"), endDate: f("2018-08-16 01:23:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -12.613217502012784)),
            GlucoseChange(startDate: f("2018-08-16 01:13:44 +0000"), endDate: f("2018-08-16 01:28:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -11.206618583133514)),
            GlucoseChange(startDate: f("2018-08-16 02:03:43 +0000"), endDate: f("2018-08-16 02:03:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 6.071196836763691)),
            GlucoseChange(startDate: f("2018-08-16 03:13:44 +0000"), endDate: f("2018-08-16 03:13:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 1.735876471025445)),
            GlucoseChange(startDate: f("2018-08-16 03:13:44 +0000"), endDate: f("2018-08-16 03:18:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 2.2702059848264096)),
            GlucoseChange(startDate: f("2018-08-16 03:13:44 +0000"), endDate: f("2018-08-16 03:23:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 3.754918289224931)),
            GlucoseChange(startDate: f("2018-08-16 03:13:44 +0000"), endDate: f("2018-08-16 03:28:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 5.444256153348801)),
            GlucoseChange(startDate: f("2018-08-16 03:13:44 +0000"), endDate: f("2018-08-16 03:33:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 11.486797488154545)),
            GlucoseChange(startDate: f("2018-08-16 03:13:44 +0000"), endDate: f("2018-08-16 03:38:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 1.7953524267912058)),
            GlucoseChange(startDate: f("2018-08-16 03:13:44 +0000"), endDate: f("2018-08-16 03:43:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 2.376773676557343)),
            GlucoseChange(startDate: f("2018-08-16 03:18:44 +0000"), endDate: f("2018-08-16 03:48:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -6.551474763321222)),
            GlucoseChange(startDate: f("2018-08-16 03:28:44 +0000"), endDate: f("2018-08-16 03:53:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -11.56463836036644)),
            GlucoseChange(startDate: f("2018-08-16 03:28:44 +0000"), endDate: f("2018-08-16 03:58:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -23.524929675277797)),
            GlucoseChange(startDate: f("2018-08-16 03:33:43 +0000"), endDate: f("2018-08-16 04:03:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -26.46553805353557)),
            GlucoseChange(startDate: f("2018-08-16 03:38:43 +0000"), endDate: f("2018-08-16 04:08:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -32.50957095033954)),
            GlucoseChange(startDate: f("2018-08-16 03:43:44 +0000"), endDate: f("2018-08-16 04:13:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -22.823727411197925)),
            GlucoseChange(startDate: f("2018-08-16 03:48:43 +0000"), endDate: f("2018-08-16 04:18:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -23.399872617600906)),
            GlucoseChange(startDate: f("2018-08-16 03:53:44 +0000"), endDate: f("2018-08-16 04:23:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -16.21261395015381)),
            GlucoseChange(startDate: f("2018-08-16 04:03:43 +0000"), endDate: f("2018-08-16 04:28:44 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -1.2556785583940788)),
            GlucoseChange(startDate: f("2018-08-16 04:03:43 +0000"), endDate: f("2018-08-16 04:33:43 +0000"), quantity: HKQuantity(unit: unit, doubleValue: -3.0507010894534323))
        ]

        let calculated = input.combinedSums(of: .minutes(30))

        XCTAssertEqual(expected, calculated)
    }


    func testNetEffect() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        let unit = HKUnit.milligramsPerDeciliter

        let input = [
            GlucoseEffect(startDate: f("2018-08-16 01:00:00 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 25)),
            GlucoseEffect(startDate: f("2018-08-16 01:05:00 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 26)),
            GlucoseEffect(startDate: f("2018-08-16 01:10:00 +0000"), quantity: HKQuantity(unit: unit, doubleValue: 27))
        ]

        let calculated = input.netEffect()

        let expected = GlucoseChange(
            startDate: f("2018-08-16 01:00:00 +0000"),
            endDate: f("2018-08-16 01:10:00 +0000"),
            quantity: HKQuantity(unit: unit, doubleValue: 2))

        XCTAssertEqual(expected, calculated)
    }

    
}
