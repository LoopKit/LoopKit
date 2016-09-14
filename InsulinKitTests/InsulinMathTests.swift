//
//  InsulinMathTests.swift
//  InsulinMathTests
//
//  Created by Nathan Racklyeft on 1/27/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
import HealthKit
import LoopKit
@testable import InsulinKit


struct NewReservoirValue: ReservoirValue {
    let startDate: Date
    let unitVolume: Double
}


class InsulinMathTests: XCTestCase {

    func loadReservoirFixture(_ resourceName: String) -> [NewReservoirValue] {

        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = DateFormatter.ISO8601LocalTime()

        return fixture.map {
            return NewReservoirValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, unitVolume: $0["amount"] as! Double)
        }
    }

    func loadDoseFixture(_ resourceName: String) -> [DoseEntry] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = DateFormatter.ISO8601LocalTime()

        return fixture.flatMap {
            guard let unit = DoseUnit(rawValue: $0["unit"] as! String),
                  let type = PumpEventType(rawValue: $0["type"] as! String)
            else {
                return nil
            }

            return DoseEntry(
                type: type,
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                endDate: dateFormatter.date(from: $0["end_at"] as! String)!,
                value: $0["amount"] as! Double,
                unit: unit,
                description: $0["description"] as? String
            )
        }
    }

    func loadInsulinValueFixture(_ resourceName: String) -> [InsulinValue] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = DateFormatter.ISO8601LocalTime()

        return fixture.map {
            return InsulinValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, value: $0["value"] as! Double)
        }
    }

    func loadGlucoseEffectFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = DateFormatter.ISO8601LocalTime()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func loadBasalRateScheduleFixture(_ resourceName: String) -> BasalRateSchedule {
        let fixture: [JSONDictionary] = loadFixture(resourceName)

        let items = fixture.map {
            return RepeatingScheduleValue(startTime: TimeInterval(minutes: $0["minutes"] as! Double), value: $0["rate"] as! Double)
        }

        return BasalRateSchedule(dailyItems: items)!
    }

    var insulinSensitivitySchedule: InsulinSensitivitySchedule {
        return InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliterUnit(), dailyItems: [RepeatingScheduleValue(startTime: 0.0, value: 40.0)])!
    }

    func testDoseEntriesFromReservoirValues() {
        let input = loadReservoirFixture("reservoir_history_with_rewind_and_prime_input")
        let output = loadDoseFixture("reservoir_history_with_rewind_and_prime_output").reversed()

        let doses = InsulinMath.doseEntriesFromReservoirValues(input)

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqualWithAccuracy(expected.value, calculated.value, accuracy: pow(10, -14))
            XCTAssertEqual(expected.unit, calculated.unit)
        }
    }

    func testContinuousReservoirValues() {
        var input = loadReservoirFixture("reservoir_history_with_rewind_and_prime_input")

        let dateFormatter = DateFormatter.ISO8601LocalTime()
        XCTAssertTrue(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T16:40:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!))

        // We don't assert whether it's "stale".
        XCTAssertTrue(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T16:40:00")!, to: dateFormatter.date(from: "2016-01-30T22:40:00")!))
        XCTAssertTrue(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T16:40:00")!))

        // The values must extend the startDate boundary
        XCTAssertFalse(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T15:00:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!))

        // (the boundary condition is GTE)
        XCTAssertTrue(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T16:00:42")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!))

        // Rises in reservoir volume taint the entire range
        XCTAssertFalse(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T15:55:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!))

        // Any values of 0 taint the entire range
        input.append(NewReservoirValue(startDate: dateFormatter.date(from: "2016-01-30T20:37:00")!, unitVolume: 0))

        XCTAssertFalse(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T16:40:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!))

        // As long as the 0 is within the date interval bounds
        XCTAssertTrue(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T16:40:00")!, to: dateFormatter.date(from: "2016-01-30T19:40:00")!))
    }

    func testNonContinuousReservoirValues() {
        let input = loadReservoirFixture("reservoir_history_with_continuity_holes")

        let dateFormatter = DateFormatter.ISO8601LocalTime()
        XCTAssertTrue(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T18:30:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!))

        XCTAssertFalse(InsulinMath.isContinuous(input, from: dateFormatter.date(from: "2016-01-30T17:30:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!))
    }

    func testIOBFromDoses() {
        let input = loadDoseFixture("normalized_doses")
        let output = loadInsulinValueFixture("iob_from_doses_output")
        let actionDuration = TimeInterval(hours: 4)

        measure {
            _ = InsulinMath.insulinOnBoardForDoses(input, actionDuration: actionDuration)
        }

        let iob = InsulinMath.insulinOnBoardForDoses(input, actionDuration: actionDuration)

        XCTAssertEqual(output.count, iob.count)

        for (expected, calculated) in zip(output, iob) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.value, calculated.value, accuracy: 0.5)
        }
    }

    func testIOBFromNoDoses() {
        let input: [DoseEntry] = []
        let actionDuration = TimeInterval(hours: 4)

        let iob = InsulinMath.insulinOnBoardForDoses(input, actionDuration: actionDuration)

        XCTAssertEqual(0, iob.count)
    }

    func testIOBFromBolus() {
        let input = loadDoseFixture("bolus_dose")

        for hours in [2, 3, 4, 5, 5.2, 6, 7] as [Double] {
            let actionDuration = TimeInterval(hours: hours)
            let output = loadInsulinValueFixture("iob_from_bolus_\(Int(actionDuration.minutes))min_output")

            let iob = InsulinMath.insulinOnBoardForDoses(input, actionDuration: actionDuration)

            XCTAssertEqual(output.count, iob.count)

            for (expected, calculated) in zip(output, iob) {
                XCTAssertEqual(expected.startDate, calculated.startDate)
                XCTAssertEqualWithAccuracy(expected.value, calculated.value, accuracy: pow(10, -14))
            }
        }
    }

    func testIOBFromReservoirDoses() {
        let input = loadDoseFixture("normalized_reservoir_history_output")
        let output = loadInsulinValueFixture("iob_from_reservoir_output")
        let actionDuration = TimeInterval(hours: 4)

        measure {
            _ = InsulinMath.insulinOnBoardForDoses(input, actionDuration: actionDuration)
        }

        let iob = InsulinMath.insulinOnBoardForDoses(input, actionDuration: actionDuration)

        XCTAssertEqual(output.count, iob.count)

        for (expected, calculated) in zip(output, iob) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.value, calculated.value, accuracy: 0.3)
        }
    }

    func testNormalizeReservoirDoses() {
        let input = loadDoseFixture("reservoir_history_with_rewind_and_prime_output")
        let output = loadDoseFixture("normalized_reservoir_history_output")
        let basals = loadBasalRateScheduleFixture("basal")

        measure {
            _ = InsulinMath.normalize(input, againstBasalSchedule: basals)
        }

        let doses = InsulinMath.normalize(input, againstBasalSchedule: basals)

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqualWithAccuracy(expected.value, calculated.value, accuracy: pow(10, -14))
            XCTAssertEqual(expected.unit, calculated.unit)
        }
    }

    func testNormalizeEdgeCaseDoses() {
        let input = loadDoseFixture("normalize_edge_case_doses_input")
        let output = loadDoseFixture("normalize_edge_case_doses_output")
        let basals = loadBasalRateScheduleFixture("basal")

        measure {
            _ = InsulinMath.normalize(input, againstBasalSchedule: basals)
        }

        let doses = InsulinMath.normalize(input, againstBasalSchedule: basals)

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value)
            XCTAssertEqual(expected.unit, calculated.unit)
        }
    }

    func testReconcileTempBasals() {
        // Fixture contains numerous overlapping temp basals, as well as a Suspend event interleaved with a temp basal
        let input = loadDoseFixture("reconcile_history_input")
        let output = loadDoseFixture("reconcile_history_output").sorted { $0.startDate < $1.startDate }

        let doses = InsulinMath.reconcileDoses(input).sorted { $0.startDate < $1.startDate }

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value)
            XCTAssertEqual(expected.unit, calculated.unit)
        }
    }

    func testGlucoseEffectFromBolus() {
        let input = loadDoseFixture("bolus_dose")
        let output = loadGlucoseEffectFixture("effect_from_bolus_output")
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule

        measure {
            _ = InsulinMath.glucoseEffectsForDoses(input, actionDuration: TimeInterval(hours: 4), insulinSensitivity: insulinSensitivitySchedule)
        }

        let effects = InsulinMath.glucoseEffectsForDoses(input, actionDuration: TimeInterval(hours: 4), insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqualWithAccuracy(Float(output.count), Float(effects.count), accuracy: 1.0)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValue(for: .milligramsPerDeciliterUnit()), calculated.quantity.doubleValue(for: .milligramsPerDeciliterUnit()), accuracy: 1.0)
        }
    }

    func testGlucoseEffectFromShortTempBasal() {
        let input = loadDoseFixture("short_basal_dose")
        let output = loadGlucoseEffectFixture("effect_from_bolus_output")
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule

        measure {
            _ = InsulinMath.glucoseEffectsForDoses(input, actionDuration: TimeInterval(hours: 4), insulinSensitivity: insulinSensitivitySchedule)
        }

        let effects = InsulinMath.glucoseEffectsForDoses(input, actionDuration: TimeInterval(hours: 4), insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValue(for: .milligramsPerDeciliterUnit()), calculated.quantity.doubleValue(for: .milligramsPerDeciliterUnit()), accuracy: pow(10, -14))
        }
    }

    func testGlucoseEffectFromTempBasal() {
        let input = loadDoseFixture("basal_dose")
        let output = loadGlucoseEffectFixture("effect_from_basal_output")
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule

        measure {
            _ = InsulinMath.glucoseEffectsForDoses(input, actionDuration: TimeInterval(hours: 4), insulinSensitivity: insulinSensitivitySchedule)
        }

        let effects = InsulinMath.glucoseEffectsForDoses(input, actionDuration: TimeInterval(hours: 4), insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliterUnit()), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliterUnit()), accuracy: 1.0, String(describing: expected.startDate))
        }
    }

    func testGlucoseEffectFromHistory() {
        let input = loadDoseFixture("normalized_doses")
        let output = loadGlucoseEffectFixture("effect_from_history_output")
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule

        measure {
            _ = InsulinMath.glucoseEffectsForDoses(input, actionDuration: TimeInterval(hours: 4), insulinSensitivity: insulinSensitivitySchedule)
        }

        let effects = InsulinMath.glucoseEffectsForDoses(input, actionDuration: TimeInterval(hours: 4), insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliterUnit()), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliterUnit()), accuracy: 1.0)
        }
    }

    func testGlucoseEffectFromNoDoses() {
        let input: [DoseEntry] = []
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule

        let effects = InsulinMath.glucoseEffectsForDoses(input, actionDuration: TimeInterval(hours: 4), insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqual(0, effects.count)
    }

    func testTotalDelivery() {
        let input = loadDoseFixture("normalize_edge_case_doses_input")
        let output = InsulinMath.totalDeliveryForDoses(input)

        XCTAssertEqualWithAccuracy(18.8, output, accuracy: pow(10, -2))
    }
}
