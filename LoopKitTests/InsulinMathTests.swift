//
//  InsulinMathTests.swift
//  InsulinMathTests
//
//  Created by Nathan Racklyeft on 1/27/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit


struct NewReservoirValue: ReservoirValue {
    let startDate: Date
    let unitVolume: Double
}

extension DoseUnit {
    var unit: HKUnit {
        switch self {
        case .units:
            return .internationalUnit()
        case .unitsPerHour:
            return HKUnit(from: "IU/hr")
        }
    }
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

                if let scheduledBasalRate = value.scheduledBasalRate {
                    obj["scheduled"] = scheduledBasalRate.doubleValue(for: HKUnit(from: "IU/hr"))
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

        return fixture.compactMap {
            guard let unit = DoseUnit(rawValue: $0["unit"] as! String),
                  let pumpType = PumpEventType(rawValue: $0["type"] as! String),
                  let type = DoseType(pumpEventType: pumpType)
            else {
                return nil
            }

            var dose = DoseEntry(
                type: type,
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                endDate: dateFormatter.date(from: $0["end_at"] as! String)!,
                value: $0["amount"] as! Double,
                unit: unit,
                description: $0["description"] as? String,
                syncIdentifier: $0["raw"] as? String
            )

            if let scheduled = $0["scheduled"] as? Double {
                dose.scheduledBasalRate = HKQuantity(unit: unit.unit, doubleValue: scheduled)
            }

            return dose
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
        return InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0.0, value: 40.0)])!
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

        let reconciled = input.reconciled()

        XCTAssertEqual(reconciledOutput.count, reconciled.count)

        for (expected, calculated) in zip(reconciledOutput, reconciled) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value)
            XCTAssertEqual(expected.unit, calculated.unit)
        }

        let normalized = reconciled.annotated(with: basals)

        XCTAssertEqual(normalizedOutput.count, normalized.count)

        for (expected, calculated) in zip(normalizedOutput, normalized) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.netBasalUnitsPerHour, accuracy: Double(Float.ulpOfOne))
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
            XCTAssertEqual(expected.value, calculated.value, accuracy: 0.4)
        }
    }

    func testNormalizeReservoirDoses() {
        let input = loadDoseFixture("reservoir_history_with_rewind_and_prime_output")
        let output = loadDoseFixture("normalized_reservoir_history_output")
        let basals = loadBasalRateScheduleFixture("basal")

        measure {
            _ = input.annotated(with: basals)
        }

        let doses = input.annotated(with: basals)

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.value, accuracy: Double(Float.ulpOfOne))
            XCTAssertEqual(expected.unit, calculated.unit)
            XCTAssertEqual(expected.scheduledBasalRate, calculated.scheduledBasalRate)
        }
    }

    func testNormalizeEdgeCaseDoses() {
        let input = loadDoseFixture("normalize_edge_case_doses_input")
        let output = loadDoseFixture("normalize_edge_case_doses_output")
        let basals = loadBasalRateScheduleFixture("basal")

        measure {
            _ = input.annotated(with: basals)
        }

        let doses = input.annotated(with: basals)

        XCTAssertEqual(output.count, doses.count)

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.unit == .units ? calculated.netBasalUnits : calculated.netBasalUnitsPerHour)
            XCTAssertEqual(expected.unit, calculated.unit)
        }
    }

    func testReconcileTempBasals() {
        // Fixture contains numerous overlapping temp basals, as well as a Suspend event interleaved with a temp basal
        let input = loadDoseFixture("reconcile_history_input")
        let output = loadDoseFixture("reconcile_history_output").sorted { $0.startDate < $1.startDate }

        let doses = input.reconciled().sorted { $0.startDate < $1.startDate }

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

        let doses = input.reconciled()

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
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: 1.0)
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
            XCTAssertEqual(expected.quantity.doubleValue(for: .milligramsPerDeciliter), calculated.quantity.doubleValue(for: .milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
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
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 1.0, String(describing: expected.startDate))
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
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 3.0)
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

    func testDosesOverlayBasalProfile() {
        let dateFormatter = ISO8601DateFormatter.localTimeDate()
        let input = loadDoseFixture("reconcile_history_output").sorted { $0.startDate < $1.startDate }
        let output = loadDoseFixture("doses_overlay_basal_profile_output")
        let basals = loadBasalRateScheduleFixture("basal")

        let doses = input.annotated(with: basals).overlayBasalSchedule(
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

            if let syncID = expected.syncIdentifier {
                XCTAssertEqual(syncID, calculated.syncIdentifier!)
            }
        }

        // Test trimming end
        let dosesTrimmedEnd = input[0..<input.count - 11].annotated(with: basals).overlayBasalSchedule(
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
        XCTAssertEqual(dosesMatchingStart.first!.startDate, dateFormatter.date(from: "2016-02-15T14:58:02")!)
    }

    func testReconcilingBasalProfileStartBeforeResume() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        // getRecentPumpEventValues
        let doses = [
            DoseEntry(type: .tempBasal, startDate: f("2018-04-04 05:14:15 +0000"), endDate: f("2018-04-04 05:44:15 +0000"), value: 1.9, unit: .unitsPerHour, syncIdentifier: "16014f0e164312", scheduledBasalRate: nil),
            DoseEntry(type: .resume, startDate: f("2018-04-04 05:11:02 +0000"), endDate: f("2018-04-04 05:11:02 +0000"), value: 0.0, unit: .units, syncIdentifier: "1f20420b160312", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-04-04 05:11:01 +0000"), endDate: f("2018-04-05 05:11:01 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "7b05410b1603122a3000", scheduledBasalRate: nil),
            DoseEntry(type: .suspend, startDate: f("2018-04-04 04:40:06 +0000"), endDate: f("2018-04-04 04:40:06 +0000"), value: 0.0, unit: .units, syncIdentifier: "1e014628150312", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-04-04 04:39:15 +0000"), endDate: f("2018-04-04 05:09:15 +0000"), value: 4.5, unit: .unitsPerHour, syncIdentifier: "16014f27154312", scheduledBasalRate: nil),
            DoseEntry(type: .bolus, startDate: f("2018-04-04 04:34:46 +0000"), endDate: f("2018-04-04 04:34:46 +0000"), value: 1.85, unit: .units, syncIdentifier: "01004a004a006d006e22354312", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-04-04 04:34:15 +0000"), endDate: f("2018-04-04 05:04:15 +0000"), value: 1.85, unit: .unitsPerHour, syncIdentifier: "16014f22154312", scheduledBasalRate: nil)
        ]

        let reconciled = [
            DoseEntry(type: .bolus,     startDate: f("2018-04-04 04:34:46 +0000"), endDate: f("2018-04-04 04:34:46 +0000"), value: 1.85, unit: .units, syncIdentifier: "01004a004a006d006e22354312", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-04-04 04:34:15 +0000"), endDate: f("2018-04-04 04:39:15 +0000"), value: 1.85, unit: .unitsPerHour, syncIdentifier: "16014f22154312", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-04-04 04:39:15 +0000"), endDate: f("2018-04-04 04:40:06 +0000"), value: 4.5, unit: .unitsPerHour, syncIdentifier: "16014f27154312", scheduledBasalRate: nil),
            DoseEntry(type: .suspend,   startDate: f("2018-04-04 04:40:06 +0000"), endDate: f("2018-04-04 05:11:02 +0000"), value: 0.0, unit: .units, syncIdentifier: "1e014628150312", scheduledBasalRate: nil),
            DoseEntry(type: .basal,     startDate: f("2018-04-04 05:11:02 +0000"), endDate: f("2018-04-04 05:14:15 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "1f20420b160312", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-04-04 05:14:15 +0000"), endDate: f("2018-04-04 05:44:15 +0000"), value: 1.9, unit: .unitsPerHour, syncIdentifier: "16014f0e164312", scheduledBasalRate: nil),
        ]

        XCTAssertEqual(reconciled, doses.reversed().reconciled())
    }

    func testReconcileMultipleResumes() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        let doses = [
            DoseEntry(type: .basal, startDate: f("2018-05-15 14:42:36 +0000"), endDate: f("2018-05-16 14:42:36 +0000"), value: 0.84999999999999998, unit: .unitsPerHour, syncIdentifier: "7b02646a070f120e2200", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:42:36 +0000"), endDate: f("2018-05-15 14:42:36 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "1600646a074f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:32:51 +0000"), endDate: f("2018-05-15 15:02:51 +0000"), value: 1.8999999999999999, unit: .unitsPerHour, syncIdentifier: "16017360074f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:32:49 +0000"), endDate: f("2018-05-15 15:02:49 +0000"), value: 1.8999999999999999, unit: .unitsPerHour, syncIdentifier: "16017160074f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-05-15 14:25:42 +0000"), endDate: f("2018-05-16 14:25:42 +0000"), value: 0.84999999999999998, unit: .unitsPerHour, syncIdentifier: "7b026a59070f120e2200", scheduledBasalRate: nil),
            DoseEntry(type: .resume, startDate: f("2018-05-15 14:24:04 +0000"), endDate: f("2018-05-15 14:24:04 +0000"), value: 0, unit: .units, syncIdentifier: "prime2", scheduledBasalRate: nil),
            DoseEntry(type: .resume, startDate: f("2018-05-15 14:22:28 +0000"), endDate: f("2018-05-15 14:22:28 +0000"), value: 0, unit: .units, syncIdentifier: "prime1", scheduledBasalRate: nil),
            DoseEntry(type: .suspend, startDate: f("2018-05-15 14:21:33 +0000"), endDate: f("2018-05-15 14:21:33 +0000"), value: 0.0, unit: .units, syncIdentifier: "21006155070f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:10:29 +0000"), endDate: f("2018-05-15 14:10:29 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16005d4a074f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-05-15 14:10:29 +0000"), endDate: f("2018-05-16 14:10:29 +0000"), value: 0.84999999999999998, unit: .unitsPerHour, syncIdentifier: "7b025d4a070f120e2200", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:05:29 +0000"), endDate: f("2018-05-15 14:35:29 +0000"), value: 2.9249999999999998, unit: .unitsPerHour, syncIdentifier: "16015d45074f12", scheduledBasalRate: nil),
        ]

        let reconciled = [
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:05:29 +0000"), endDate: f("2018-05-15 14:10:29 +0000"), value: 2.9249999999999998, unit: .unitsPerHour, description: nil, syncIdentifier: "16015d45074f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:10:29 +0000"), endDate: f("2018-05-15 14:10:29 +0000"), value: 0.0, unit: .unitsPerHour, description: nil, syncIdentifier: "16005d4a074f12", scheduledBasalRate: nil),
            DoseEntry(type: .suspend, startDate: f("2018-05-15 14:21:33 +0000"), endDate: f("2018-05-15 14:22:28 +0000"), value: 0.0, unit: .units, description: nil, syncIdentifier: "21006155070f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-05-15 14:25:42 +0000"), endDate: f("2018-05-15 14:32:49 +0000"), value: 0.84999999999999998, unit: .unitsPerHour, description: nil, syncIdentifier: "7b026a59070f120e2200", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:32:49 +0000"), endDate: f("2018-05-15 14:32:51 +0000"), value: 1.8999999999999999, unit: .unitsPerHour, description: nil, syncIdentifier: "16017160074f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:32:51 +0000"), endDate: f("2018-05-15 14:42:36 +0000"), value: 1.8999999999999999, unit: .unitsPerHour, description: nil, syncIdentifier: "16017360074f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-05-15 14:42:36 +0000"), endDate: f("2018-05-16 14:42:36 +0000"), value: 0.84999999999999998, unit: .unitsPerHour, description: nil, syncIdentifier: "7b02646a070f120e2200", scheduledBasalRate: nil)
        ]

        XCTAssertEqual(reconciled, doses.reversed().reconciled())
    }

    func testSuspendAndBasalProfileStartInteraction() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        let doses = [
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 05:02:15 +0000"), endDate: f("2018-07-11 05:32:15 +0000"), value: 0.0, unit: .unitsPerHour,     scheduledBasalRate: nil),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 05:01:14 +0000"), endDate: f("2018-07-12 05:01:14 +0000"), value: 1.2, unit: .unitsPerHour),
            DoseEntry(type: .resume,    startDate: f("2018-07-11 05:01:14 +0000"), endDate: f("2018-07-11 05:01:14 +0000"), value: 0.0, unit: .units),
            DoseEntry(type: .suspend,   startDate: f("2018-07-11 04:31:55 +0000"), endDate: f("2018-07-11 04:31:55 +0000"), value: 0.0, unit: .units),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 04:12:15 +0000"), endDate: f("2018-07-12 04:12:15 +0000"), value: 1.2, unit: .unitsPerHour),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 04:12:15 +0000"), endDate: f("2018-07-11 04:12:15 +0000"), value: 0.0, unit: .unitsPerHour),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 04:07:15 +0000"), endDate: f("2018-07-11 04:37:15 +0000"), value: 0.67500000000000004, unit: .unitsPerHour),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 04:00:00 +0000"), endDate: f("2018-07-12 04:00:00 +0000"), value: 1.2, unit: .unitsPerHour),
        ]

        let reconciled = [
            DoseEntry(type: .basal,     startDate: f("2018-07-11 04:00:00 +0000"), endDate: f("2018-07-11 04:07:15 +0000"), value: 1.2,   unit: .unitsPerHour),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 04:07:15 +0000"), endDate: f("2018-07-11 04:12:15 +0000"), value: 0.67500000000000004, unit: .unitsPerHour),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 04:12:15 +0000"), endDate: f("2018-07-11 04:31:55 +0000"), value: 1.2,   unit: .unitsPerHour),
            DoseEntry(type: .suspend,   startDate: f("2018-07-11 04:31:55 +0000"), endDate: f("2018-07-11 05:01:14 +0000"), value: 0.0,   unit: .units),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 05:01:14 +0000"), endDate: f("2018-07-11 05:02:15 +0000"), value: 1.2,   unit: .unitsPerHour),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 05:02:15 +0000"), endDate: f("2018-07-11 05:32:15 +0000"), value: 0.0, unit: .unitsPerHour)
        ]

        XCTAssertEqual(reconciled, doses.reversed().reconciled())
    }

    func testOverlayBasalScheduleWithSuspend() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        let reconciled = [
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 04:07:15 +0000"), endDate: f("2018-07-11 04:12:15 +0000"), value: 0.67500000000000004, unit: .unitsPerHour),
            DoseEntry(type: .suspend,   startDate: f("2018-07-11 04:31:55 +0000"), endDate: f("2018-07-11 05:01:14 +0000"), value: 0.0,   unit: .units),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 05:02:15 +0000"), endDate: f("2018-07-11 05:32:15 +0000"), value: 0.0, unit: .unitsPerHour)
        ]

        let reconciledWithBasal = [
            DoseEntry(type: .basal,     startDate: f("2018-07-11 04:00:00 +0000"), endDate: f("2018-07-11 04:07:15 +0000"), value: 1.2,   unit: .unitsPerHour, syncIdentifier: "BasalRateSchedule 2018-07-11T04:00:00Z 2018-07-11T04:07:15Z"),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 04:07:15 +0000"), endDate: f("2018-07-11 04:12:15 +0000"), value: 0.67500000000000004, unit: .unitsPerHour),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 04:12:15 +0000"), endDate: f("2018-07-11 04:31:55 +0000"), value: 1.2,   unit: .unitsPerHour, syncIdentifier: "BasalRateSchedule 2018-07-11T04:12:15Z 2018-07-11T04:31:55Z"),
            DoseEntry(type: .suspend,   startDate: f("2018-07-11 04:31:55 +0000"), endDate: f("2018-07-11 05:01:14 +0000"), value: 0.0,   unit: .units),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 05:01:14 +0000"), endDate: f("2018-07-11 05:02:15 +0000"), value: 1.2,   unit: .unitsPerHour, syncIdentifier: "BasalRateSchedule 2018-07-11T05:01:14Z 2018-07-11T05:02:15Z"),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 05:02:15 +0000"), endDate: f("2018-07-11 05:32:15 +0000"), value: 0.0, unit: .unitsPerHour)
        ]

        let basalSchedule = BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: 0, value: 1.2)])

        XCTAssertEqual(reconciledWithBasal, reconciled.overlayBasalSchedule(basalSchedule!, startingAt: f("2018-07-11 04:00:00 +0000"), endingAt: f("2018-07-11 05:32:15 +0000"), insertingBasalEntries: true))
    }
}
