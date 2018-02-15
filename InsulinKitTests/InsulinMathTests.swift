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
    
    private func printInsulinValues(_ insulinValues: [InsulinValue]) {
        print("\n\n")
        print(String(data: try! JSONSerialization.data(
            withJSONObject: insulinValues.map({ (value) -> [String: Any] in
                return [
                    "date": ISO8601DateFormatter.localTimeDate().string(from: value.startDate),
                    "value": value.value,
                    "unit": "U"
                ]
            }),
            options: .prettyPrinted), encoding: .utf8)!)
        print("\n\n")
    }

    private func printDoses(_ doses: [DoseEntry]) {
        print("\n\n")
        print(String(data: try! JSONSerialization.data(
            withJSONObject: doses.map({ (value) -> [String: Any] in
                var obj: [String: Any] = [
                    "type": value.type.pumpEventType!.rawValue,
                    "start_at": ISO8601DateFormatter.localTimeDate().string(from: value.startDate),
                    "end_at": ISO8601DateFormatter.localTimeDate().string(from: value.endDate),
                    "amount": value.value,
                    "unit": value.unit.rawValue
                ]

                if let syncIdentifier = value.syncIdentifier {
                    obj["raw"] = syncIdentifier
                }

                return obj
            }),
            options: .prettyPrinted), encoding: .utf8)!)
        print("\n\n")
    }

    func loadReservoirFixture(_ resourceName: String) -> [NewReservoirValue] {

        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return NewReservoirValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, unitVolume: $0["amount"] as! Double)
        }
    }

    func loadDoseFixture(_ resourceName: String) -> [DoseEntry] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.flatMap {
            guard let unit = DoseUnit(rawValue: $0["unit"] as! String),
                  let pumpType = PumpEventType(rawValue: $0["type"] as! String),
                  let type = DoseType(pumpEventType: pumpType)
            else {
                return nil
            }

            return DoseEntry(
                type: type,
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                endDate: dateFormatter.date(from: $0["end_at"] as! String)!,
                value: $0["amount"] as! Double,
                unit: unit,
                description: $0["description"] as? String,
                syncIdentifier: $0["raw"] as? String,
                managedObjectID: nil
            )
        }
    }

    func loadInsulinValueFixture(_ resourceName: String) -> [InsulinValue] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return InsulinValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, value: $0["value"] as! Double)
        }
    }

    func loadGlucoseEffectFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

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
        return InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter(), dailyItems: [RepeatingScheduleValue(startTime: 0.0, value: 40.0)])!
    }

    func testDoseEntriesFromReservoirValues() {
        let input = loadReservoirFixture("reservoir_history_with_rewind_and_prime_input")
        let output = loadDoseFixture("reservoir_history_with_rewind_and_prime_output").reversed()

        let doses = input.doseEntries

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value, accuracy: Double(Float.ulpOfOne))
            XCTAssertEqual(expected.unit, calculated.unit)
        }
    }

    func testContinuousReservoirValues() {
        var input = loadReservoirFixture("reservoir_history_with_rewind_and_prime_input")
        let within = TimeInterval(minutes: 30)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()
        XCTAssertTrue(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T16:40:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!, within: within))

        // We don't assert whether it's "stale".
        XCTAssertTrue(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T16:40:00")!, to: dateFormatter.date(from: "2016-01-30T22:40:00")!, within: within))
        XCTAssertTrue(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T16:40:00")!, to: Date(), within: within))

        // The values must extend the startDate boundary
        XCTAssertFalse(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T15:00:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!, within: within))

        // (the boundary condition is GTE)
        XCTAssertTrue(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T16:00:42")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!, within: within))

        // Rises in reservoir volume taint the entire range
        XCTAssertFalse(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T15:55:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!, within: within))

        // Any values of 0 taint the entire range
        input.append(NewReservoirValue(startDate: dateFormatter.date(from: "2016-01-30T20:37:00")!, unitVolume: 0))

        XCTAssertFalse(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T16:40:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!, within: within))

        // As long as the 0 is within the date interval bounds
        XCTAssertTrue(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T16:40:00")!, to: dateFormatter.date(from: "2016-01-30T19:40:00")!, within: within))
    }

    func testNonContinuousReservoirValues() {
        let input = loadReservoirFixture("reservoir_history_with_continuity_holes")

        let dateFormatter = ISO8601DateFormatter.localTimeDate()
        XCTAssertTrue(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T18:30:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!, within: .minutes(30)))

        XCTAssertFalse(input.isContinuous(from: dateFormatter.date(from: "2016-01-30T17:30:00")!, to: dateFormatter.date(from: "2016-01-30T20:40:00")!, within: .minutes(30)))
    }

    func testIOBFromSuspend() {
        let input = loadDoseFixture("suspend_dose")
        let reconciledOutput = loadDoseFixture("suspend_dose_reconciled")
        let normalizedOutput = loadDoseFixture("suspend_dose_reconciled_normalized")
        let iobOutput = loadInsulinValueFixture("suspend_dose_reconciled_normalized_iob")
        let basals = loadBasalRateScheduleFixture("basal")
        let insulinModel = WalshInsulinModel(actionDuration: TimeInterval(hours: 4))

        let reconciled = input.reconcile()

        XCTAssertEqual(reconciledOutput.count, reconciled.count)

        for (expected, calculated) in zip(reconciledOutput, reconciled) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value)
            XCTAssertEqual(expected.unit, calculated.unit)
        }

        let normalized = reconciled.normalize(against: basals)

        XCTAssertEqual(normalizedOutput.count, normalized.count)

        for (expected, calculated) in zip(normalizedOutput, normalized) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value, accuracy: Double(Float.ulpOfOne))
            XCTAssertEqual(expected.unit, calculated.unit)
        }

        let iob = normalized.insulinOnBoard(model: insulinModel)

        XCTAssertEqual(iobOutput.count, iob.count)

        for (expected, calculated) in zip(iobOutput, iob) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.value, calculated.value, accuracy: Double(Float.ulpOfOne))
        }
    }

    func testIOBFromDoses() {
        let input = loadDoseFixture("normalized_doses")
        let output = loadInsulinValueFixture("iob_from_doses_output")
        let insulinModel = WalshInsulinModel(actionDuration: TimeInterval(hours: 4))

        measure {
            _ = input.insulinOnBoard(model: insulinModel)
        }

        let iob = input.insulinOnBoard(model: insulinModel)

        XCTAssertEqual(output.count, iob.count)

        for (expected, calculated) in zip(output, iob) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.value, calculated.value, accuracy: 0.5)
        }
    }

    func testIOBFromNoDoses() {
        let input: [DoseEntry] = []
        let insulinModel = WalshInsulinModel(actionDuration: TimeInterval(hours: 4))

        let iob = input.insulinOnBoard(model: insulinModel)

        XCTAssertEqual(0, iob.count)
    }
    
    func testInsulinOnBoardLimitsForExponentialModel() {
        let insulinModel = ExponentialInsulinModel(actionDuration: TimeInterval(minutes: 360), peakActivityTime: TimeInterval(minutes: 75))
        
        XCTAssertEqual(1, insulinModel.percentEffectRemaining(at: .minutes(-1)), accuracy: 0.001)
        XCTAssertEqual(1, insulinModel.percentEffectRemaining(at: .minutes(0)), accuracy: 0.001)
        XCTAssertEqual(0, insulinModel.percentEffectRemaining(at: .minutes(360)), accuracy: 0.001)
        XCTAssertEqual(0, insulinModel.percentEffectRemaining(at: .minutes(361)), accuracy: 0.001)
        
        // Test random point
        XCTAssertEqual(0.5110493617156, insulinModel.percentEffectRemaining(at: .minutes(108)), accuracy: 0.001)

    }
    
    func testIOBFromDosesExponential() {
        let input = loadDoseFixture("normalized_doses")
        let output = loadInsulinValueFixture("iob_from_doses_exponential_output")
        let insulinModel = ExponentialInsulinModel(actionDuration: TimeInterval(minutes: 360), peakActivityTime: TimeInterval(minutes: 75))
        
        measure {
            _ = input.insulinOnBoard(model: insulinModel)
        }
        
        let iob = input.insulinOnBoard(model: insulinModel)
        
        XCTAssertEqual(output.count, iob.count)
        
        for (expected, calculated) in zip(output, iob) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.value, calculated.value, accuracy: 0.5)
        }
    }

    func testIOBFromBolusExponential() {
        let input = loadDoseFixture("bolus_dose")
        
        let insulinModel = ExponentialInsulinModel(actionDuration: TimeInterval(minutes: 360), peakActivityTime: TimeInterval(minutes: 75))
        let output = loadInsulinValueFixture("iob_from_bolus_exponential_output")
        
        let iob = input.insulinOnBoard(model: insulinModel)
        
        XCTAssertEqual(output.count, iob.count)
        
        for (expected, calculated) in zip(output, iob) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.value, calculated.value, accuracy: Double(Float.ulpOfOne))
        }
    }


    func testIOBFromBolus() {
        let input = loadDoseFixture("bolus_dose")

        for hours in [2, 3, 4, 5, 5.2, 6, 7] as [Double] {
            let actionDuration = TimeInterval(hours: hours)
            let insulinModel = WalshInsulinModel(actionDuration: actionDuration)
            let output = loadInsulinValueFixture("iob_from_bolus_\(Int(actionDuration.minutes))min_output")

            let iob = input.insulinOnBoard(model: insulinModel)

            XCTAssertEqual(output.count, iob.count)

            for (expected, calculated) in zip(output, iob) {
                XCTAssertEqual(expected.startDate, calculated.startDate)
                XCTAssertEqual(expected.value, calculated.value, accuracy: Double(Float.ulpOfOne))
            }
        }
    }

    func testIOBFromReservoirDoses() {
        let input = loadDoseFixture("normalized_reservoir_history_output")
        let output = loadInsulinValueFixture("iob_from_reservoir_output")
        let insulinModel = WalshInsulinModel(actionDuration: TimeInterval(hours: 4))

        measure {
            _ = input.insulinOnBoard(model: insulinModel)
        }

        let iob = input.insulinOnBoard(model: insulinModel)

        XCTAssertEqual(output.count, iob.count)

        for (expected, calculated) in zip(output, iob) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.value, calculated.value, accuracy: 0.3)
        }
    }

    func testNormalizeReservoirDoses() {
        let input = loadDoseFixture("reservoir_history_with_rewind_and_prime_output")
        let output = loadDoseFixture("normalized_reservoir_history_output")
        let basals = loadBasalRateScheduleFixture("basal")

        measure {
            _ = input.normalize(against: basals)
        }

        let doses = input.normalize(against: basals)

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value, accuracy: Double(Float.ulpOfOne))
            XCTAssertEqual(expected.unit, calculated.unit)
        }
    }

    func testNormalizeEdgeCaseDoses() {
        let input = loadDoseFixture("normalize_edge_case_doses_input")
        let output = loadDoseFixture("normalize_edge_case_doses_output")
        let basals = loadBasalRateScheduleFixture("basal")

        measure {
            _ = input.normalize(against: basals)
        }

        let doses = input.normalize(against: basals)

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

        let doses = input.reconcile().sorted { $0.startDate < $1.startDate }

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value)
            XCTAssertEqual(expected.unit, calculated.unit)
            XCTAssertEqual(expected.syncIdentifier, calculated.syncIdentifier)
        }
    }

    func testReconcileResumeBeforeRewind() {
        let input = loadDoseFixture("reconcile_resume_before_rewind_input")
        let output = loadDoseFixture("reconcile_resume_before_rewind_output")

        let doses = input.reconcile()

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value)
            XCTAssertEqual(expected.unit, calculated.unit)
            XCTAssertEqual(expected.syncIdentifier, calculated.syncIdentifier)
        }

        printDoses(doses)
    }

    func testGlucoseEffectFromBolus() {
        let input = loadDoseFixture("bolus_dose")
        let output = loadGlucoseEffectFixture("effect_from_bolus_output")
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule
        let insulinModel = WalshInsulinModel(actionDuration: TimeInterval(hours: 4))

        measure {
            _ = input.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)
        }

        let effects = input.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqual(Float(output.count), Float(effects.count), accuracy: 1.0)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter()), calculated.quantity.doubleValue(for: .milligramsPerDeciliter()), accuracy: 1.0)
        }
    }

    func testGlucoseEffectFromShortTempBasal() {
        let input = loadDoseFixture("short_basal_dose")
        let output = loadGlucoseEffectFixture("effect_from_bolus_output")
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule
        let insulinModel = WalshInsulinModel(actionDuration: TimeInterval(hours: 4))

        measure {
            _ = input.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)
        }

        let effects = input.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter()), calculated.quantity.doubleValue(for: .milligramsPerDeciliter()), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testGlucoseEffectFromTempBasal() {
        let input = loadDoseFixture("basal_dose")
        let output = loadGlucoseEffectFixture("effect_from_basal_output")
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule
        let insulinModel = WalshInsulinModel(actionDuration: TimeInterval(hours: 4))

        measure {
            _ = input.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)
        }

        let effects = input.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter()), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter()), accuracy: 1.0, String(describing: expected.startDate))
        }
    }

    func testGlucoseEffectFromHistory() {
        let input = loadDoseFixture("normalized_doses")
        let output = loadGlucoseEffectFixture("effect_from_history_output")
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule
        let insulinModel = WalshInsulinModel(actionDuration: TimeInterval(hours: 4))

        measure {
            _ = input.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)
        }

        let effects = input.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter()), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter()), accuracy: 1.0)
        }
    }

    func testGlucoseEffectFromNoDoses() {
        let input: [DoseEntry] = []
        let insulinSensitivitySchedule = self.insulinSensitivitySchedule
        let insulinModel = WalshInsulinModel(actionDuration: TimeInterval(hours: 4))

        let effects = input.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)

        XCTAssertEqual(0, effects.count)
    }

    func testTotalDelivery() {
        let input = loadDoseFixture("normalize_edge_case_doses_input")
        let output = input.totalDelivery

        XCTAssertEqual(18.8, output, accuracy: 0.01)
    }

    func testTrimContinuingDoses() {
        let dateFormatter = ISO8601DateFormatter.localTimeDate()
        let input = loadDoseFixture("normalized_doses")

        // Last temp ends at 2015-10-15T18:14:35
        let endDate = dateFormatter.date(from: "2015-10-15T18:00:00")!
        let trimmed = input.map { $0.trim(to: endDate) }

        XCTAssertEqual(endDate, trimmed.last!.endDate)
        XCTAssertEqual(input.count, trimmed.count)
    }

    @available(iOS 11.0, *)
    func testDosesOverlayBasalProfile() {
        let dateFormatter = ISO8601DateFormatter.localTimeDate()
        let input = loadDoseFixture("reconcile_history_output").sorted { $0.startDate < $1.startDate }
        let output = loadDoseFixture("doses_overlay_basal_profile_output")
        let basals = loadBasalRateScheduleFixture("basal")

        let doses = input.overlayBasalSchedule(
            basals,
            // A start date before the first entry should generate a basal
            startingAt: dateFormatter.date(from: "2016-02-15T14:01:04")!,
            endingAt: Date(),
            insertingBasalEntries: true
        )

        XCTAssertEqual(output.count, doses.count)

        XCTAssertEqual(doses.first?.startDate, dateFormatter.date(from: "2016-02-15T14:01:04")!)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value)
            XCTAssertEqual(expected.unit, calculated.unit)
        }

        // Test trimming end
        let dosesTrimmedEnd = input[0..<input.count - 11].overlayBasalSchedule(
            basals,
            startingAt: dateFormatter.date(from: "2016-02-15T14:01:04")!,
            // An end date before some input entries should omit them
            endingAt: dateFormatter.date(from: "2016-02-15T19:45:00")!,
            insertingBasalEntries: true
        )

        XCTAssertEqual(output.count - 14, dosesTrimmedEnd.count)
        // The BasalProfileStart event shouldn't be generated
        XCTAssertEqual(dosesTrimmedEnd.last!.endDate, dateFormatter.date(from: "2016-02-15T19:36:11")!)

        // Test a start date equal to the first entry, the expected case
        let dosesMatchingStart = input.overlayBasalSchedule(
            basals,
            startingAt: dateFormatter.date(from: "2016-02-15T15:06:05")!,
            endingAt: Date(),
            insertingBasalEntries: true
        )

        // The inserted entries aren't included
        XCTAssertEqual(output.count - 2, dosesMatchingStart.count)
        XCTAssertEqual(dosesMatchingStart.first!.startDate, dateFormatter.date(from: "2016-02-15T15:06:05")!)
    }
}
