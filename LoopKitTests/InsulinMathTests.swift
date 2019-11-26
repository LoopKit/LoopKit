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

    var fixtureDateformatter: DateFormatter!
    
    private let fixtureTimeZone = TimeZone(secondsFromGMT: -0 * 60 * 60)!

    private func fixtureDate(_ input: String) -> Date {
        return fixtureDateformatter.date(from: input)!
    }

    override func setUp() {
        fixtureDateformatter = DateFormatter.descriptionFormatter
        fixtureDateformatter.timeZone = fixtureTimeZone
    }
    
    private func printInsulinValues(_ insulinValues: [InsulinValue]) {
        print("\n\n")
        print(String(data: try! JSONSerialization.data(
            withJSONObject: insulinValues.map({ (value) -> [String: Any] in
                return [
                    "date": ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone).string(from: value.startDate),
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
                    "start_at": ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone).string(from: value.startDate),
                    "end_at": ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone).string(from: value.endDate),
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
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

        return fixture.map {
            return NewReservoirValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, unitVolume: $0["amount"] as! Double)
        }
    }

    func loadDoseFixture(_ resourceName: String) -> [DoseEntry] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

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
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

        return fixture.map {
            return InsulinValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, value: $0["value"] as! Double)
        }
    }

    func loadGlucoseEffectFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func loadBasalRateScheduleFixture(_ resourceName: String) -> BasalRateSchedule {
        let fixture: [JSONDictionary] = loadFixture(resourceName)

        let items = fixture.map {
            return RepeatingScheduleValue(startTime: TimeInterval(minutes: $0["minutes"] as! Double), value: $0["rate"] as! Double)
        }

        return BasalRateSchedule(dailyItems: items, timeZone: fixtureTimeZone)!
    }

    var insulinSensitivitySchedule: InsulinSensitivitySchedule {
        return InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0.0, value: 40.0)], timeZone: fixtureTimeZone)!
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
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)
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

        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)
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

        // Total delivery on split doses should add up to delivery from original doses
        XCTAssertEqual(
            input.map {$0.unitsInDeliverableIncrements}.reduce(0,+),
            doses.map {$0.unitsInDeliverableIncrements}.reduce(0,+),
            accuracy: Double(Float.ulpOfOne))

        for (expected, calculated) in zip(output, doses) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.endDate, calculated.endDate)
            XCTAssertEqual(expected.value, calculated.unitsPerHour, accuracy: Double(Float.ulpOfOne))
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
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)
        let input = loadDoseFixture("normalized_doses").reversed()

        // Last temp ends at 2015-10-15T22:29:50
        let endDate = dateFormatter.date(from: "2015-10-15T22:25:50")!
        let trimmed = input.map { $0.trimmed(to: endDate) }

        print(input, "\n\n\n")
        print(trimmed)

        XCTAssertEqual(endDate, trimmed.last!.endDate)
        XCTAssertEqual(input.count, trimmed.count)
    }

    func testDosesOverlayBasalProfile() {
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: fixtureTimeZone)
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
            DoseEntry(type: .bolus,     startDate: f("2018-04-04 04:34:46 +0000"), endDate: f("2018-04-04 04:34:46 +0000"), value: 1.85, unit: .units, deliveredUnits: 1.85, syncIdentifier: "01004a004a006d006e22354312", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-04-04 04:34:15 +0000"), endDate: f("2018-04-04 04:39:15 +0000"), value: 1.85, unit: .unitsPerHour, deliveredUnits: 0.15, syncIdentifier: "16014f22154312", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-04-04 04:39:15 +0000"), endDate: f("2018-04-04 04:40:06 +0000"), value: 4.5, unit: .unitsPerHour, deliveredUnits: 0.05, syncIdentifier: "16014f27154312", scheduledBasalRate: nil),
            DoseEntry(type: .suspend,   startDate: f("2018-04-04 04:40:06 +0000"), endDate: f("2018-04-04 05:11:02 +0000"), value: 0.0, unit: .units, deliveredUnits: 0.0, syncIdentifier: "1e014628150312", scheduledBasalRate: nil),
            DoseEntry(type: .basal,     startDate: f("2018-04-04 05:11:02 +0000"), endDate: f("2018-04-04 05:14:15 +0000"), value: 1.2, unit: .unitsPerHour, deliveredUnits: 0.06433333333333334, syncIdentifier: "1f20420b160312", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-04-04 05:14:15 +0000"), endDate: f("2018-04-04 05:44:15 +0000"), value: 1.9, unit: .unitsPerHour, deliveredUnits: 0.95, syncIdentifier: "16014f0e164312", scheduledBasalRate: nil),
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
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:05:29 +0000"), endDate: f("2018-05-15 14:10:29 +0000"), value: 2.9249999999999998, unit: .unitsPerHour, deliveredUnits: 0.25, description: nil, syncIdentifier: "16015d45074f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:10:29 +0000"), endDate: f("2018-05-15 14:10:29 +0000"), value: 0.0, unit: .unitsPerHour, deliveredUnits: 0.0, description: nil, syncIdentifier: "16005d4a074f12", scheduledBasalRate: nil),
            DoseEntry(type: .suspend, startDate: f("2018-05-15 14:21:33 +0000"), endDate: f("2018-05-15 14:22:28 +0000"), value: 0.0, unit: .units, deliveredUnits: 0.0, description: nil, syncIdentifier: "21006155070f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-05-15 14:25:42 +0000"), endDate: f("2018-05-15 14:32:49 +0000"), value: 0.84999999999999998, unit: .unitsPerHour, deliveredUnits: 0.10081944444444443,description: nil, syncIdentifier: "7b026a59070f120e2200", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:32:49 +0000"), endDate: f("2018-05-15 14:32:51 +0000"), value: 1.8999999999999999, unit: .unitsPerHour, deliveredUnits: 0.0, description: nil, syncIdentifier: "16017160074f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-05-15 14:32:51 +0000"), endDate: f("2018-05-15 14:42:36 +0000"), value: 1.8999999999999999, unit: .unitsPerHour, deliveredUnits: 0.3, description: nil, syncIdentifier: "16017360074f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-05-15 14:42:36 +0000"), endDate: f("2018-05-16 14:42:36 +0000"), value: 0.84999999999999998, unit: .unitsPerHour, deliveredUnits: 20.4, description: nil, syncIdentifier: "7b02646a070f120e2200", scheduledBasalRate: nil)
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
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 04:07:15 +0000"), endDate: f("2018-07-11 04:37:15 +0000"), value: 0.675, unit: .unitsPerHour),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 04:00:00 +0000"), endDate: f("2018-07-12 04:00:00 +0000"), value: 1.2, unit: .unitsPerHour),
        ]

        let reconciled = [
            DoseEntry(type: .basal,     startDate: f("2018-07-11 04:00:00 +0000"), endDate: f("2018-07-11 04:07:15 +0000"), value: 1.2,   unit: .unitsPerHour, deliveredUnits: 0.145),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 04:07:15 +0000"), endDate: f("2018-07-11 04:12:15 +0000"), value: 0.675, unit: .unitsPerHour, deliveredUnits: 0.05),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 04:12:15 +0000"), endDate: f("2018-07-11 04:31:55 +0000"), value: 1.2,   unit: .unitsPerHour, deliveredUnits: 0.3933333333333333),
            DoseEntry(type: .suspend,   startDate: f("2018-07-11 04:31:55 +0000"), endDate: f("2018-07-11 05:01:14 +0000"), value: 0.0,   unit: .units,        deliveredUnits: 0.0),
            DoseEntry(type: .basal,     startDate: f("2018-07-11 05:01:14 +0000"), endDate: f("2018-07-11 05:02:15 +0000"), value: 1.2,   unit: .unitsPerHour, deliveredUnits: 0.02033333333333333),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-11 05:02:15 +0000"), endDate: f("2018-07-11 05:32:15 +0000"), value: 0.0,   unit: .unitsPerHour, deliveredUnits: 0.0)
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

    func testAppendedUnionOfPumpEvents() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }
        let unit = DoseEntry.unitsPerHour

        let normalizedDoseEntries = [
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 03:34:29 +0000"), endDate: f("2018-07-15 03:54:29 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015de2144e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 03:54:29 +0000"), endDate: f("2018-07-15 04:14:31 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015df6144e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:14:31 +0000"), endDate: f("2018-07-15 04:29:28 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015fce154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 04:29:28 +0000"), endDate: f("2018-07-15 04:44:28 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "7b055cdd150e122a3000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:44:28 +0000"), endDate: f("2018-07-15 04:49:29 +0000"), value: 3.6499999999999999, unit: .unitsPerHour, syncIdentifier: "16015cec154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:49:29 +0000"), endDate: f("2018-07-15 04:54:28 +0000"), value: 3.8500000000000001, unit: .unitsPerHour, syncIdentifier: "16015df1154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:54:28 +0000"), endDate: f("2018-07-15 04:59:28 +0000"), value: 3.5750000000000002, unit: .unitsPerHour, syncIdentifier: "16015cf6154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 05:00:01 +0000"), endDate: f("2018-07-15 05:00:01 +0000"), value: 3.0, unit: .units, syncIdentifier: "0100780078004c0041c0364e12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:59:28 +0000"), endDate: f("2018-07-15 05:04:29 +0000"), value: 3.1000000000000001, unit: .unitsPerHour, syncIdentifier: "16015cfb154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 05:04:29 +0000"), endDate: f("2018-07-15 05:24:29 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015dc4164e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 05:24:29 +0000"), endDate: f("2018-07-15 05:44:29 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015dd8164e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 05:44:29 +0000"), endDate: f("2018-07-15 05:59:29 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015dec164e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 05:59:29 +0000"), endDate: f("2018-07-15 06:04:29 +0000"), value: 0.625, unit: .unitsPerHour, syncIdentifier: "16015dfb164e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:04:29 +0000"), endDate: f("2018-07-15 06:09:29 +0000"), value: 0.17499999999999999, unit: .unitsPerHour, syncIdentifier: "16015dc4174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:09:29 +0000"), endDate: f("2018-07-15 06:14:29 +0000"), value: 1.95, unit: .unitsPerHour, syncIdentifier: "16015dc9174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:14:29 +0000"), endDate: f("2018-07-15 06:19:29 +0000"), value: 0.59999999999999998, unit: .unitsPerHour, syncIdentifier: "16015dce174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:19:29 +0000"), endDate: f("2018-07-15 06:24:29 +0000"), value: 1.8999999999999999, unit: .unitsPerHour, syncIdentifier: "16015dd3174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:24:29 +0000"), endDate: f("2018-07-15 06:29:29 +0000"), value: 3.9750000000000001, unit: .unitsPerHour, syncIdentifier: "16015dd8174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:29:29 +0000"), endDate: f("2018-07-15 06:34:28 +0000"), value: 4.0499999999999998, unit: .unitsPerHour, syncIdentifier: "16015ddd174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:34:28 +0000"), endDate: f("2018-07-15 06:39:28 +0000"), value: 3.0499999999999998, unit: .unitsPerHour, syncIdentifier: "16015ce2174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:39:28 +0000"), endDate: f("2018-07-15 06:44:29 +0000"), value: 3.625, unit: .unitsPerHour, syncIdentifier: "16015ce7174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:44:29 +0000"), endDate: f("2018-07-15 06:49:31 +0000"), value: 2.7999999999999998, unit: .unitsPerHour, syncIdentifier: "16015dec174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:49:31 +0000"), endDate: f("2018-07-15 06:54:30 +0000"), value: 1.9750000000000001, unit: .unitsPerHour, syncIdentifier: "16015ff1174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 06:54:30 +0000"), endDate: f("2018-07-15 07:00:00 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "7b055ef6170e122a3000", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 07:00:00 +0000"), endDate: f("2018-07-15 07:09:28 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "7b0040c0000f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:09:28 +0000"), endDate: f("2018-07-15 07:14:28 +0000"), value: 0.45000000000000001, unit: .unitsPerHour, syncIdentifier: "16015cc9004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:14:28 +0000"), endDate: f("2018-07-15 07:19:29 +0000"), value: 0.5, unit: .unitsPerHour, syncIdentifier: "16015cce004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 07:19:29 +0000"), endDate: f("2018-07-15 07:24:29 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "7b005dd3000f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:24:29 +0000"), endDate: f("2018-07-15 07:29:28 +0000"), value: 2.1499999999999999, unit: .unitsPerHour, syncIdentifier: "16015dd8004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 07:29:29 +0000"), endDate: f("2018-07-15 07:34:29 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "7b005ddd000f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:34:29 +0000"), endDate: f("2018-07-15 07:39:29 +0000"), value: 1.825, unit: .unitsPerHour, syncIdentifier: "16015de2004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:39:29 +0000"), endDate: f("2018-07-15 07:44:28 +0000"), value: 2.5249999999999999, unit: .unitsPerHour, syncIdentifier: "16015de7004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:44:28 +0000"), endDate: f("2018-07-15 07:49:28 +0000"), value: 2.5499999999999998, unit: .unitsPerHour, syncIdentifier: "16015cec004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:49:28 +0000"), endDate: f("2018-07-15 07:54:28 +0000"), value: 2.6000000000000001, unit: .unitsPerHour, syncIdentifier: "16015cf1004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:54:28 +0000"), endDate: f("2018-07-15 07:59:31 +0000"), value: 2.625, unit: .unitsPerHour, syncIdentifier: "16015cf6004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:59:31 +0000"), endDate: f("2018-07-15 08:04:30 +0000"), value: 2.2250000000000001, unit: .unitsPerHour, syncIdentifier: "16015ffb004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:04:30 +0000"), endDate: f("2018-07-15 08:09:28 +0000"), value: 2.3500000000000001, unit: .unitsPerHour, syncIdentifier: "16015ec4014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:09:28 +0000"), endDate: f("2018-07-15 08:14:28 +0000"), value: 2.3250000000000002, unit: .unitsPerHour, syncIdentifier: "16015cc9014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:14:28 +0000"), endDate: f("2018-07-15 08:19:28 +0000"), value: 1.925, unit: .unitsPerHour, syncIdentifier: "16015cce014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 08:19:29 +0000"), endDate: f("2018-07-15 08:24:29 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "7b005dd3010f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:24:29 +0000"), endDate: f("2018-07-15 08:29:29 +0000"), value: 1.8500000000000001, unit: .unitsPerHour, syncIdentifier: "16015dd8014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:29:29 +0000"), endDate: f("2018-07-15 08:34:15 +0000"), value: 2.2250000000000001, unit: .unitsPerHour, syncIdentifier: "16015ddd014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 08:34:15 +0000"), endDate: f("2018-07-15 08:49:14 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "7b004fe2010f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:49:14 +0000"), endDate: f("2018-07-15 08:54:14 +0000"), value: 2.5, unit: .unitsPerHour, syncIdentifier: "16014ef1014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:54:14 +0000"), endDate: f("2018-07-15 08:59:15 +0000"), value: 3.4500000000000002, unit: .unitsPerHour, syncIdentifier: "16014ef6014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:59:15 +0000"), endDate: f("2018-07-15 09:04:14 +0000"), value: 3.5750000000000002, unit: .unitsPerHour, syncIdentifier: "16014ffb014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 09:04:14 +0000"), endDate: f("2018-07-15 09:09:15 +0000"), value: 2.875, unit: .unitsPerHour, syncIdentifier: "16014ec4024f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 09:09:15 +0000"), endDate: f("2018-07-15 10:00:00 +0000"), value: 1.2, unit: .unitsPerHour, syncIdentifier: "7b004fc9020f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 10:00:00 +0000"), endDate: f("2018-07-15 11:09:15 +0000"), value: 1.0, unit: .unitsPerHour, syncIdentifier: "7b0140c0030f12062800", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:09:15 +0000"), endDate: f("2018-07-15 11:14:14 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16014fc9044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 11:14:15 +0000"), endDate: f("2018-07-15 11:39:14 +0000"), value: 1.0, unit: .unitsPerHour, syncIdentifier: "7b014fce040f12062800", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:39:14 +0000"), endDate: f("2018-07-15 11:44:14 +0000"), value: 2.4750000000000001, unit: .unitsPerHour, syncIdentifier: "16014ee7044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:44:14 +0000"), endDate: f("2018-07-15 11:49:15 +0000"), value: 2.3999999999999999, unit: .unitsPerHour, syncIdentifier: "16014eec044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:49:15 +0000"), endDate: f("2018-07-15 11:54:14 +0000"), value: 2.3250000000000002, unit: .unitsPerHour, syncIdentifier: "16014ff1044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:54:14 +0000"), endDate: f("2018-07-15 11:59:15 +0000"), value: 2.0499999999999998, unit: .unitsPerHour, syncIdentifier: "16014ef6044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 11:59:15 +0000"), endDate: f("2018-07-15 14:00:00 +0000"), value: 1.0, unit: .unitsPerHour, syncIdentifier: "7b014ffb040f12062800", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 14:00:00 +0000"), endDate: f("2018-07-15 14:09:48 +0000"), value: 0.90000000000000002, unit: .unitsPerHour, syncIdentifier: "7b0240c0070f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 14:09:48 +0000"), endDate: f("2018-07-15 14:14:15 +0000"), value: 2.0499999999999998, unit: .unitsPerHour, syncIdentifier: "160170c9074f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 14:14:15 +0000"), endDate: f("2018-07-15 15:29:15 +0000"), value: 0.90000000000000002, unit: .unitsPerHour, syncIdentifier: "7b024fce070f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 15:29:15 +0000"), endDate: f("2018-07-15 15:34:14 +0000"), value: 1.8999999999999999, unit: .unitsPerHour, syncIdentifier: "16014fdd084f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 15:34:15 +0000"), endDate: f("2018-07-15 15:39:14 +0000"), value: 0.90000000000000002, unit: .unitsPerHour, syncIdentifier: "7b024fe2080f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 15:39:14 +0000"), endDate: f("2018-07-15 15:44:14 +0000"), value: 1.95, unit: .unitsPerHour, syncIdentifier: "16014ee7084f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 15:44:14 +0000"), endDate: f("2018-07-15 15:49:14 +0000"), value: 2.1499999999999999, unit: .unitsPerHour, syncIdentifier: "16014eec084f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 15:49:33 +0000"), endDate: f("2018-07-15 15:49:33 +0000"), value: 2.4500000000000002, unit: .units, syncIdentifier: "010062006200000061f1284f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 15:49:14 +0000"), endDate: f("2018-07-15 15:54:16 +0000"), value: 1.95, unit: .unitsPerHour, syncIdentifier: "16014ef1084f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 15:54:16 +0000"), endDate: f("2018-07-15 16:14:15 +0000"), value: 0.90000000000000002, unit: .unitsPerHour, syncIdentifier: "7b0250f6080f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 16:14:15 +0000"), endDate: f("2018-07-15 16:34:15 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16014fce094f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 16:34:15 +0000"), endDate: f("2018-07-15 16:44:14 +0000"), value: 0.90000000000000002, unit: .unitsPerHour, syncIdentifier: "7b024fe2090f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 16:44:14 +0000"), endDate: f("2018-07-15 17:14:14 +0000"), value: 4.6500000000000004, unit: .unitsPerHour, syncIdentifier: "16014eec094f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 17:55:12 +0000"), endDate: f("2018-07-15 17:55:12 +0000"), value: 2.5499999999999998, unit: .units, syncIdentifier: "01006600660029004cf72a4f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 17:14:15 +0000"), endDate: f("2018-07-15 18:30:00 +0000"), value: 0.90000000000000002, unit: .unitsPerHour, syncIdentifier: "7b024fce0a0f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 18:30:00 +0000"), endDate: f("2018-07-15 18:59:15 +0000"), value: 0.80000000000000004, unit: .unitsPerHour, syncIdentifier: "7b0340de0b0f12172000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 18:59:15 +0000"), endDate: f("2018-07-15 19:04:15 +0000"), value: 4.6500000000000004, unit: .unitsPerHour, syncIdentifier: "16014ffb0b4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:04:15 +0000"), endDate: f("2018-07-15 19:09:14 +0000"), value: 3.9750000000000001, unit: .unitsPerHour, syncIdentifier: "16014fc40c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:09:14 +0000"), endDate: f("2018-07-15 19:19:15 +0000"), value: 4.6500000000000004, unit: .unitsPerHour, syncIdentifier: "16014ec90c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 19:19:15 +0000"), endDate: f("2018-07-15 19:24:15 +0000"), value: 0.80000000000000004, unit: .unitsPerHour, syncIdentifier: "7b034fd30c0f12172000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:24:15 +0000"), endDate: f("2018-07-15 19:29:14 +0000"), value: 2.7749999999999999, unit: .unitsPerHour, syncIdentifier: "16014fd80c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:29:14 +0000"), endDate: f("2018-07-15 19:34:14 +0000"), value: 4.6500000000000004, unit: .unitsPerHour, syncIdentifier: "16014edd0c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:34:14 +0000"), endDate: f("2018-07-15 19:39:14 +0000"), value: 4.625, unit: .unitsPerHour, syncIdentifier: "16014ee20c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:39:14 +0000"), endDate: f("2018-07-15 19:44:15 +0000"), value: 2.6000000000000001, unit: .unitsPerHour, syncIdentifier: "16014ee70c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 19:44:15 +0000"), endDate: f("2018-07-15 20:04:15 +0000"), value: 0.80000000000000004, unit: .unitsPerHour, syncIdentifier: "7b034fec0c0f12172000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 20:04:15 +0000"), endDate: f("2018-07-15 20:23:00 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16014fc40d4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 20:23:00 +0000"), endDate: f("2018-07-15 20:29:15 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "160140d70d4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 20:29:15 +0000"), endDate: f("2018-07-15 20:49:14 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16014fdd0d4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 20:49:14 +0000"), endDate: f("2018-07-15 21:09:14 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16014ef10d4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 21:09:14 +0000"), endDate: f("2018-07-15 21:29:30 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16014ec90e4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 21:29:31 +0000"), endDate: f("2018-07-15 21:30:00 +0000"), value: 0.80000000000000004, unit: .unitsPerHour, syncIdentifier: "7b035fdd0e0f12172000", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 21:30:00 +0000"), endDate: f("2018-07-15 21:49:29 +0000"), value: 0.90000000000000002, unit: .unitsPerHour, syncIdentifier: "7b0440de0e0f121d2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 21:49:29 +0000"), endDate: f("2018-07-15 21:54:32 +0000"), value: 2.75, unit: .unitsPerHour, syncIdentifier: "16015df10e4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 21:54:32 +0000"), endDate: f("2018-07-15 21:59:29 +0000"), value: 3.0499999999999998, unit: .unitsPerHour, syncIdentifier: "160160f60e4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 21:59:29 +0000"), endDate: f("2018-07-15 22:04:31 +0000"), value: 3.2250000000000001, unit: .unitsPerHour, syncIdentifier: "16015dfb0e4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:04:31 +0000"), endDate: f("2018-07-15 22:09:31 +0000"), value: 4.5999999999999996, unit: .unitsPerHour, syncIdentifier: "16015fc40f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:09:31 +0000"), endDate: f("2018-07-15 22:14:32 +0000"), value: 4.3250000000000002, unit: .unitsPerHour, syncIdentifier: "16015fc90f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:14:32 +0000"), endDate: f("2018-07-15 22:19:30 +0000"), value: 3.875, unit: .unitsPerHour, syncIdentifier: "160160ce0f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:19:30 +0000"), endDate: f("2018-07-15 22:24:29 +0000"), value: 3.5249999999999999, unit: .unitsPerHour, syncIdentifier: "16015ed30f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:24:29 +0000"), endDate: f("2018-07-15 22:29:46 +0000"), value: 3.2000000000000002, unit: .unitsPerHour, syncIdentifier: "16015dd80f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:29:46 +0000"), endDate: f("2018-07-15 22:34:45 +0000"), value: 2.1499999999999999, unit: .unitsPerHour, syncIdentifier: "16016edd0f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 22:34:45 +0000"), endDate: f("2018-07-15 22:39:29 +0000"), value: 0.90000000000000002, unit: .unitsPerHour, syncIdentifier: "7b046de20f0f121d2400", scheduledBasalRate: nil),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 22:54:39 +0000"), endDate: f("2018-07-15 22:54:39 +0000"), value: 2.8500000000000001, unit: .units, syncIdentifier: "010072007200000067f62f4f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:39:29 +0000"), endDate: f("2018-07-15 23:01:42 +0000"), value: 0.40000000000000002, unit: .unitsPerHour, syncIdentifier: "16015de70f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:01:42 +0000"), endDate: f("2018-07-15 23:24:29 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16016ac1104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:24:29 +0000"), endDate: f("2018-07-15 23:29:44 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015dd8104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:29:44 +0000"), endDate: f("2018-07-15 23:34:28 +0000"), value: 1.55, unit: .unitsPerHour, syncIdentifier: "16016cdd104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:34:28 +0000"), endDate: f("2018-07-15 23:39:29 +0000"), value: 1.625, unit: .unitsPerHour, syncIdentifier: "16015ce2104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 23:43:57 +0000"), endDate: f("2018-07-15 23:43:57 +0000"), value: 1.5, unit: .units, syncIdentifier: "01003c003c00620079eb304f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:39:29 +0000"), endDate: f("2018-07-15 23:49:29 +0000"), value: 1.55, unit: .unitsPerHour, syncIdentifier: "16015de7104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-16 00:02:37 +0000"), endDate: f("2018-07-16 00:02:37 +0000"), value: 2.6000000000000001, unit: .units, syncIdentifier: "010068006800910065c2314f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:49:29 +0000"), endDate: f("2018-07-16 00:04:42 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015df1104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 00:04:42 +0000"), endDate: f("2018-07-16 00:09:29 +0000"), value: 0.025000000000000001, unit: .unitsPerHour, syncIdentifier: "16016ac4114f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-16 00:20:20 +0000"), endDate: f("2018-07-16 00:20:20 +0000"), value: 1.1499999999999999, unit: .units, syncIdentifier: "01002e002e00e70054d4314f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-16 00:09:29 +0000"), endDate: f("2018-07-16 00:24:32 +0000"), value: 0.90000000000000002, unit: .unitsPerHour, syncIdentifier: "7b045dc9110f121d2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 00:24:32 +0000"), endDate: f("2018-07-16 00:44:28 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "160160d8114f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 00:44:28 +0000"), endDate: f("2018-07-16 01:04:29 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015cec114f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 01:04:29 +0000"), endDate: f("2018-07-16 01:27:16 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015dc4124f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 01:27:16 +0000"), endDate: f("2018-07-16 01:49:29 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "160150db124f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-16 01:58:53 +0000"), endDate: f("2018-07-16 01:58:53 +0000"), value: 3.6499999999999999, unit: .units, syncIdentifier: "010092009200730075fa324f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 01:49:29 +0000"), endDate: f("2018-07-16 02:04:30 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "16015df1124f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 02:04:30 +0000"), endDate: f("2018-07-16 02:33:36 +0000"), value: 1.7250000000000001, unit: .unitsPerHour, syncIdentifier: "16015ec4134f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .suspend, startDate: f("2018-07-16 02:33:36 +0000"), endDate: f("2018-07-16 02:33:36 +0000"), value: 0.0, unit: .unitsPerHour, syncIdentifier: "1e0164e1130f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
        ]

        let cachedDoseEntries = [
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 03:34:29 +0000"), endDate: f("2018-07-15 03:54:29 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015de2144e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 03:54:29 +0000"), endDate: f("2018-07-15 04:14:31 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015df6144e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:14:31 +0000"), endDate: f("2018-07-15 04:29:28 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015fce154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 04:29:28 +0000"), endDate: f("2018-07-15 04:44:28 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "7b055cdd150e122a3000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:44:28 +0000"), endDate: f("2018-07-15 04:49:29 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "16015cec154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:49:29 +0000"), endDate: f("2018-07-15 04:54:28 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "16015df1154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:54:28 +0000"), endDate: f("2018-07-15 04:59:28 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "16015cf6154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 04:59:28 +0000"), endDate: f("2018-07-15 05:04:29 +0000"), value: 0.25, unit: .units, syncIdentifier: "16015cfb154e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 05:00:01 +0000"), endDate: f("2018-07-15 05:00:01 +0000"), value: 3.0, unit: .units, syncIdentifier: "0100780078004c0041c0364e12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 05:04:29 +0000"), endDate: f("2018-07-15 05:24:29 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015dc4164e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 05:24:29 +0000"), endDate: f("2018-07-15 05:44:29 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015dd8164e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 05:44:29 +0000"), endDate: f("2018-07-15 05:59:29 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015dec164e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 05:59:29 +0000"), endDate: f("2018-07-15 06:04:29 +0000"), value: 0.050000000000000003, unit: .units, syncIdentifier: "16015dfb164e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:04:29 +0000"), endDate: f("2018-07-15 06:09:29 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015dc4174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:09:29 +0000"), endDate: f("2018-07-15 06:14:29 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16015dc9174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:14:29 +0000"), endDate: f("2018-07-15 06:19:29 +0000"), value: 0.050000000000000003, unit: .units, syncIdentifier: "16015dce174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:19:29 +0000"), endDate: f("2018-07-15 06:24:29 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16015dd3174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:24:29 +0000"), endDate: f("2018-07-15 06:29:29 +0000"), value: 0.34999999999999998, unit: .units, syncIdentifier: "16015dd8174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:29:29 +0000"), endDate: f("2018-07-15 06:34:28 +0000"), value: 0.34999999999999998, unit: .units, syncIdentifier: "16015ddd174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:34:28 +0000"), endDate: f("2018-07-15 06:39:28 +0000"), value: 0.25, unit: .units, syncIdentifier: "16015ce2174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:39:28 +0000"), endDate: f("2018-07-15 06:44:29 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "16015ce7174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:44:29 +0000"), endDate: f("2018-07-15 06:49:31 +0000"), value: 0.25, unit: .units, syncIdentifier: "16015dec174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 06:49:31 +0000"), endDate: f("2018-07-15 06:54:30 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16015ff1174e12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 06:54:30 +0000"), endDate: f("2018-07-15 07:00:00 +0000"), value: 0.10000000000000001, unit: .units, syncIdentifier: "7b055ef6170e122a3000", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 07:00:00 +0000"), endDate: f("2018-07-15 07:09:28 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "7b0040c0000f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:09:28 +0000"), endDate: f("2018-07-15 07:14:28 +0000"), value: 0.050000000000000003, unit: .units, syncIdentifier: "16015cc9004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:14:28 +0000"), endDate: f("2018-07-15 07:19:29 +0000"), value: 0.050000000000000003, unit: .units, syncIdentifier: "16015cce004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 07:19:29 +0000"), endDate: f("2018-07-15 07:24:29 +0000"), value: 0.10000000000000001, unit: .units, syncIdentifier: "7b005dd3000f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:24:29 +0000"), endDate: f("2018-07-15 07:29:28 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16015dd8004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 07:29:29 +0000"), endDate: f("2018-07-15 07:34:29 +0000"), value: 0.10000000000000001, unit: .units, syncIdentifier: "7b005ddd000f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:34:29 +0000"), endDate: f("2018-07-15 07:39:29 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16015de2004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:39:29 +0000"), endDate: f("2018-07-15 07:44:28 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16015de7004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:44:28 +0000"), endDate: f("2018-07-15 07:49:28 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16015cec004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:49:28 +0000"), endDate: f("2018-07-15 07:54:28 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16015cf1004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:54:28 +0000"), endDate: f("2018-07-15 07:59:31 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16015cf6004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 07:59:31 +0000"), endDate: f("2018-07-15 08:04:30 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16015ffb004f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:04:30 +0000"), endDate: f("2018-07-15 08:09:28 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16015ec4014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:09:28 +0000"), endDate: f("2018-07-15 08:14:28 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16015cc9014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:14:28 +0000"), endDate: f("2018-07-15 08:19:28 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16015cce014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 08:19:29 +0000"), endDate: f("2018-07-15 08:24:29 +0000"), value: 0.10000000000000001, unit: .units, syncIdentifier: "7b005dd3010f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:24:29 +0000"), endDate: f("2018-07-15 08:29:29 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16015dd8014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:29:29 +0000"), endDate: f("2018-07-15 08:34:15 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16015ddd014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 08:34:15 +0000"), endDate: f("2018-07-15 08:49:14 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "7b004fe2010f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:49:14 +0000"), endDate: f("2018-07-15 08:54:14 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16014ef1014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:54:14 +0000"), endDate: f("2018-07-15 08:59:15 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "16014ef6014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 08:59:15 +0000"), endDate: f("2018-07-15 09:04:14 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "16014ffb014f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 09:04:14 +0000"), endDate: f("2018-07-15 09:09:15 +0000"), value: 0.25, unit: .units, syncIdentifier: "16014ec4024f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 09:09:15 +0000"), endDate: f("2018-07-15 10:00:00 +0000"), value: 1.0, unit: .units, syncIdentifier: "7b004fc9020f12003000", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 10:00:00 +0000"), endDate: f("2018-07-15 11:09:15 +0000"), value: 1.1499999999999999, unit: .units, syncIdentifier: "7b0140c0030f12062800", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:09:15 +0000"), endDate: f("2018-07-15 11:14:14 +0000"), value: 0.0, unit: .units, syncIdentifier: "16014fc9044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 11:14:15 +0000"), endDate: f("2018-07-15 11:39:14 +0000"), value: 0.40000000000000002, unit: .units, syncIdentifier: "7b014fce040f12062800", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:39:14 +0000"), endDate: f("2018-07-15 11:44:14 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16014ee7044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:44:14 +0000"), endDate: f("2018-07-15 11:49:15 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16014eec044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:49:15 +0000"), endDate: f("2018-07-15 11:54:14 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16014ff1044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 11:54:14 +0000"), endDate: f("2018-07-15 11:59:15 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16014ef6044f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 11:59:15 +0000"), endDate: f("2018-07-15 14:00:00 +0000"), value: 2.0, unit: .units, syncIdentifier: "7b014ffb040f12062800", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 14:00:00 +0000"), endDate: f("2018-07-15 14:09:48 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "7b0240c0070f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 14:09:48 +0000"), endDate: f("2018-07-15 14:14:15 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "160170c9074f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 14:14:15 +0000"), endDate: f("2018-07-15 15:29:15 +0000"), value: 1.1499999999999999, unit: .units, syncIdentifier: "7b024fce070f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 15:29:15 +0000"), endDate: f("2018-07-15 15:34:14 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16014fdd084f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 15:34:15 +0000"), endDate: f("2018-07-15 15:39:14 +0000"), value: 0.050000000000000003, unit: .units, syncIdentifier: "7b024fe2080f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 15:39:14 +0000"), endDate: f("2018-07-15 15:44:14 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16014ee7084f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 15:44:14 +0000"), endDate: f("2018-07-15 15:49:14 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16014eec084f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 15:49:14 +0000"), endDate: f("2018-07-15 15:54:16 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16014ef1084f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 15:49:33 +0000"), endDate: f("2018-07-15 15:49:33 +0000"), value: 2.4500000000000002, unit: .units, syncIdentifier: "010062006200000061f1284f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 15:54:16 +0000"), endDate: f("2018-07-15 16:14:15 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "7b0250f6080f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 16:14:15 +0000"), endDate: f("2018-07-15 16:34:15 +0000"), value: 0.0, unit: .units, syncIdentifier: "16014fce094f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 16:34:15 +0000"), endDate: f("2018-07-15 16:44:14 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "7b024fe2090f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 16:44:14 +0000"), endDate: f("2018-07-15 17:14:14 +0000"), value: 2.3500000000000001, unit: .units, syncIdentifier: "16014eec094f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 17:14:15 +0000"), endDate: f("2018-07-15 18:30:00 +0000"), value: 1.1499999999999999, unit: .units, syncIdentifier: "7b024fce0a0f120e2400", scheduledBasalRate: nil),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 17:55:12 +0000"), endDate: f("2018-07-15 17:55:12 +0000"), value: 2.5499999999999998, unit: .units, syncIdentifier: "01006600660029004cf72a4f12", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 18:30:00 +0000"), endDate: f("2018-07-15 18:59:15 +0000"), value: 0.40000000000000002, unit: .units, syncIdentifier: "7b0340de0b0f12172000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 18:59:15 +0000"), endDate: f("2018-07-15 19:04:15 +0000"), value: 0.40000000000000002, unit: .units, syncIdentifier: "16014ffb0b4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:04:15 +0000"), endDate: f("2018-07-15 19:09:14 +0000"), value: 0.34999999999999998, unit: .units, syncIdentifier: "16014fc40c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:09:14 +0000"), endDate: f("2018-07-15 19:19:15 +0000"), value: 0.80000000000000004, unit: .units, syncIdentifier: "16014ec90c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 19:19:15 +0000"), endDate: f("2018-07-15 19:24:15 +0000"), value: 0.050000000000000003, unit: .units, syncIdentifier: "7b034fd30c0f12172000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:24:15 +0000"), endDate: f("2018-07-15 19:29:14 +0000"), value: 0.25, unit: .units, syncIdentifier: "16014fd80c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:29:14 +0000"), endDate: f("2018-07-15 19:34:14 +0000"), value: 0.40000000000000002, unit: .units, syncIdentifier: "16014edd0c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:34:14 +0000"), endDate: f("2018-07-15 19:39:14 +0000"), value: 0.40000000000000002, unit: .units, syncIdentifier: "16014ee20c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 19:39:14 +0000"), endDate: f("2018-07-15 19:44:15 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16014ee70c4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 19:44:15 +0000"), endDate: f("2018-07-15 20:04:15 +0000"), value: 0.25, unit: .units, syncIdentifier: "7b034fec0c0f12172000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 20:04:15 +0000"), endDate: f("2018-07-15 20:23:00 +0000"), value: 0.0, unit: .units, syncIdentifier: "16014fc40d4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 20:23:00 +0000"), endDate: f("2018-07-15 20:29:15 +0000"), value: 0.0, unit: .units, syncIdentifier: "160140d70d4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 20:29:15 +0000"), endDate: f("2018-07-15 20:49:14 +0000"), value: 0.0, unit: .units, syncIdentifier: "16014fdd0d4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 20:49:14 +0000"), endDate: f("2018-07-15 21:09:14 +0000"), value: 0.0, unit: .units, syncIdentifier: "16014ef10d4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 21:09:14 +0000"), endDate: f("2018-07-15 21:29:30 +0000"), value: 0.0, unit: .units, syncIdentifier: "16014ec90e4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.8)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 21:29:31 +0000"), endDate: f("2018-07-15 21:30:00 +0000"), value: 0.0, unit: .units, syncIdentifier: "7b035fdd0e0f12172000", scheduledBasalRate: nil),
            DoseEntry(type: .basal, startDate: f("2018-07-15 21:30:00 +0000"), endDate: f("2018-07-15 21:49:29 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "7b0440de0e0f121d2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 21:49:29 +0000"), endDate: f("2018-07-15 21:54:32 +0000"), value: 0.25, unit: .units, syncIdentifier: "16015df10e4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 21:54:32 +0000"), endDate: f("2018-07-15 21:59:29 +0000"), value: 0.25, unit: .units, syncIdentifier: "160160f60e4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 21:59:29 +0000"), endDate: f("2018-07-15 22:04:31 +0000"), value: 0.25, unit: .units, syncIdentifier: "16015dfb0e4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:04:31 +0000"), endDate: f("2018-07-15 22:09:31 +0000"), value: 0.40000000000000002, unit: .units, syncIdentifier: "16015fc40f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:09:31 +0000"), endDate: f("2018-07-15 22:14:32 +0000"), value: 0.34999999999999998, unit: .units, syncIdentifier: "16015fc90f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:14:32 +0000"), endDate: f("2018-07-15 22:19:30 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "160160ce0f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:19:30 +0000"), endDate: f("2018-07-15 22:24:29 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "16015ed30f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:24:29 +0000"), endDate: f("2018-07-15 22:29:46 +0000"), value: 0.29999999999999999, unit: .units, syncIdentifier: "16015dd80f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:29:46 +0000"), endDate: f("2018-07-15 22:34:45 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16016edd0f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-15 22:34:45 +0000"), endDate: f("2018-07-15 22:39:29 +0000"), value: 0.050000000000000003, unit: .units, syncIdentifier: "7b046de20f0f121d2400", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 22:39:29 +0000"), endDate: f("2018-07-15 23:01:42 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16015de70f4f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 22:54:39 +0000"), endDate: f("2018-07-15 22:54:39 +0000"), value: 2.8500000000000001, unit: .units, syncIdentifier: "010072007200000067f62f4f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:01:42 +0000"), endDate: f("2018-07-15 23:24:29 +0000"), value: 0.0, unit: .units, syncIdentifier: "16016ac1104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:24:29 +0000"), endDate: f("2018-07-15 23:29:44 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015dd8104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:29:44 +0000"), endDate: f("2018-07-15 23:34:28 +0000"), value: 0.10000000000000001, unit: .units, syncIdentifier: "16016cdd104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:34:28 +0000"), endDate: f("2018-07-15 23:39:29 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16015ce2104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:39:29 +0000"), endDate: f("2018-07-15 23:49:29 +0000"), value: 0.25, unit: .units, syncIdentifier: "16015de7104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-15 23:43:57 +0000"), endDate: f("2018-07-15 23:43:57 +0000"), value: 1.5, unit: .units, syncIdentifier: "01003c003c00620079eb304f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-15 23:49:29 +0000"), endDate: f("2018-07-16 00:04:42 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015df1104f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-16 00:02:37 +0000"), endDate: f("2018-07-16 00:02:37 +0000"), value: 2.6000000000000001, unit: .units, syncIdentifier: "010068006800910065c2314f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 00:04:42 +0000"), endDate: f("2018-07-16 00:09:29 +0000"), value: 0.0, unit: .units, syncIdentifier: "16016ac4114f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .basal, startDate: f("2018-07-16 00:09:29 +0000"), endDate: f("2018-07-16 00:24:32 +0000"), value: 0.25, unit: .units, syncIdentifier: "7b045dc9110f121d2400", scheduledBasalRate: nil),
            DoseEntry(type: .bolus, startDate: f("2018-07-16 00:20:20 +0000"), endDate: f("2018-07-16 00:20:20 +0000"), value: 1.1499999999999999, unit: .units, syncIdentifier: "01002e002e00e70054d4314f12", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 00:24:32 +0000"), endDate: f("2018-07-16 00:44:28 +0000"), value: 0.0, unit: .units, syncIdentifier: "160160d8114f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 00:44:28 +0000"), endDate: f("2018-07-16 01:04:29 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015cec114f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 01:04:29 +0000"), endDate: f("2018-07-16 01:27:16 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015dc4124f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 01:27:16 +0000"), endDate: f("2018-07-16 01:49:29 +0000"), value: 0.0, unit: .units, syncIdentifier: "160150db124f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 01:49:29 +0000"), endDate: f("2018-07-16 02:04:30 +0000"), value: 0.0, unit: .units, syncIdentifier: "16015df1124f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 0.9)),
            DoseEntry(type: .bolus, startDate: f("2018-07-16 01:58:53 +0000"), endDate: f("2018-07-16 01:58:53 +0000"), value: 3.6499999999999999, unit: .units, syncIdentifier: "010092009200730075fa324f12", scheduledBasalRate: nil),
        ]

        XCTAssertEqual(f("2018-07-16 02:04:30 +0000"), cachedDoseEntries.lastBasalEndDate!)

        let appended = cachedDoseEntries.appendedUnion(with: normalizedDoseEntries)
        XCTAssertEqual(appended.count, normalizedDoseEntries.count)
        XCTAssertEqual(
            appended,
            cachedDoseEntries.appendedUnion(with: normalizedDoseEntries.filterDateRange(cachedDoseEntries.lastBasalEndDate, nil)),
            "Filtering has the same outcome"
        )

        let insulinModel = ExponentialInsulinModel(actionDuration: TimeInterval(minutes: 360), peakActivityTime: TimeInterval(minutes: 75))
        let date = f("2018-07-16 03:40:00 +0000")

        XCTAssertEqual(
            normalizedDoseEntries.insulinOnBoard(model: insulinModel, from: date, to: date).first!.value,
            appended.insulinOnBoard(model: insulinModel, from: date, to: date).first!.value,
            accuracy: 1.0/40
        )

        let emptyCacheAppended = ([DoseEntry]()).appendedUnion(with: normalizedDoseEntries)

        XCTAssertEqual(
            normalizedDoseEntries.insulinOnBoard(model: insulinModel, from: date, to: date).first!.value,
            emptyCacheAppended.insulinOnBoard(model: insulinModel, from: date, to: date).first!.value,
            accuracy: 1.0/40,
            "Empty cache doesn't affect outcome"
        )

        let fullCache = cachedDoseEntries.appendedUnion(with: [])

        XCTAssertEqual(
            cachedDoseEntries.insulinOnBoard(model: insulinModel, from: date, to: date).first!.value,
            fullCache.insulinOnBoard(model: insulinModel, from: date, to: date).first!.value,
            accuracy: 1.0/40,
            "Only cache doesn't affect outcome"
        )
    }

    func testAppendedUnionOfReservoirEvents() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }
        let unit = DoseEntry.unitsPerHour

        let normalizedReservoirDoseEntries = [
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 03:59:00 +0000"), endDate: f("2018-07-16 04:04:00 +0000"), value: 2.4000000000000341, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:04:00 +0000"), endDate: f("2018-07-16 04:09:00 +0000"), value: 2.3999999999998636, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:09:00 +0000"), endDate: f("2018-07-16 04:14:00 +0000"), value: 1.2000000000001023, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:14:00 +0000"), endDate: f("2018-07-16 04:19:00 +0000"), value: 2.4000000000000341, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:19:00 +0000"), endDate: f("2018-07-16 04:24:00 +0000"), value: 2.3999999999998636, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:24:00 +0000"), endDate: f("2018-07-16 04:29:00 +0000"), value: 1.2000000000001023, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:29:00 +0000"), endDate: f("2018-07-16 04:34:00 +0000"), value: 0.0, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:34:00 +0000"), endDate: f("2018-07-16 04:39:00 +0000"), value: 0.0, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:39:00 +0000"), endDate: f("2018-07-16 04:44:00 +0000"), value: 0.0, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:44:00 +0000"), endDate: f("2018-07-16 04:49:00 +0000"), value: 0.0, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:49:00 +0000"), endDate: f("2018-07-16 04:54:00 +0000"), value: 0.0, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:54:00 +0000"), endDate: f("2018-07-16 04:59:00 +0000"), value: 0.0, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:59:00 +0000"), endDate: f("2018-07-16 05:04:00 +0000"), value: 0.0, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 05:04:00 +0000"), endDate: f("2018-07-16 05:09:00 +0000"), value: 0.0, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 05:09:00 +0000"), endDate: f("2018-07-16 05:14:00 +0000"), value: 0.0, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 05:14:00 +0000"), endDate: f("2018-07-16 05:19:00 +0000"), value: 1.1999999999999318, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 05:19:00 +0000"), endDate: f("2018-07-16 05:24:00 +0000"), value: 1.2000000000001023, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 05:24:00 +0000"), endDate: f("2018-07-16 05:29:00 +0000"), value: 1.1999999999999318, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
        ]

        let cachedDoseEntries = [
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 03:59:15 +0000"), endDate: f("2018-07-16 04:04:14 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16014ffb144f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:04:14 +0000"), endDate: f("2018-07-16 04:09:15 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16014ec4154f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:09:15 +0000"), endDate: f("2018-07-16 04:14:14 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16014fc9154f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:14:14 +0000"), endDate: f("2018-07-16 04:19:14 +0000"), value: 0.20000000000000001, unit: .units, syncIdentifier: "16014ece154f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:19:14 +0000"), endDate: f("2018-07-16 04:24:15 +0000"), value: 0.14999999999999999, unit: .units, syncIdentifier: "16014ed3154f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .basal, startDate: f("2018-07-16 04:24:15 +0000"), endDate: f("2018-07-16 04:29:14 +0000"), value: 0.10000000000000001, unit: .units, syncIdentifier: "7b054fd8150f122a3000", scheduledBasalRate: nil),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:29:14 +0000"), endDate: f("2018-07-16 04:49:15 +0000"), value: 0.0, unit: .units, syncIdentifier: "16014edd154f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 04:49:15 +0000"), endDate: f("2018-07-16 05:09:15 +0000"), value: 0.0, unit: .units, syncIdentifier: "16014ff1154f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
            DoseEntry(type: .tempBasal, startDate: f("2018-07-16 05:09:15 +0000"), endDate: f("2018-07-16 05:14:15 +0000"), value: 0.0, unit: .units, syncIdentifier: "16014fc9164f12", scheduledBasalRate: HKQuantity(unit: unit, doubleValue: 1.2)),
        ]

        XCTAssertEqual(f("2018-07-16 05:14:15 +0000"), cachedDoseEntries.lastBasalEndDate!)

        let appended = cachedDoseEntries + normalizedReservoirDoseEntries.filterDateRange(cachedDoseEntries.lastBasalEndDate!, nil).map({ $0.trimmed(from: cachedDoseEntries.lastBasalEndDate!) })
        XCTAssertEqual(appended.count, cachedDoseEntries.count + 3, "The last 4 reservoir doses should be appended")

        let insulinModel = ExponentialInsulinModel(actionDuration: TimeInterval(minutes: 360), peakActivityTime: TimeInterval(minutes: 75))
        let date = f("2018-07-16 05:30:00 +0000")

        XCTAssertEqual(
            normalizedReservoirDoseEntries.insulinOnBoard(model: insulinModel, from: date, to: date).first!.value,
            appended.insulinOnBoard(model: insulinModel, from: date, to: date).first!.value,
            accuracy: 0.1
        )
    }

    func testNetBasalUnits() {
        let startDate = fixtureDate("2018-07-16 03:49:00 +0000")
        let endDate = startDate.addingTimeInterval(TimeInterval(minutes: 5))

        let scheduledRate = 0.15 // Scheduled amount = 0.15 U/hr = 3 pulses per hour, actual expected 522 delivery over 5m = 0 pulses = 0 U
        let tempBasalRate = 0.4 // Temp rate = 0.4 U/hr = 8 pulses per hour, actual expected 522 delivery over 5m = 1 pulses = 0.05 U
        let netRate = tempBasalRate - scheduledRate

        let dose = DoseEntry(type: .tempBasal, startDate: startDate, endDate: endDate, value: tempBasalRate, unit: .unitsPerHour, scheduledBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: scheduledRate))

        XCTAssertEqual(netRate, dose.netBasalUnitsPerHour, accuracy: .ulpOfOne)
        XCTAssertEqual(0.0375, dose.netBasalUnits, accuracy: .ulpOfOne)
    }

    func testDoseEntryUnitsInDeliverableIncrements() {

        let makeDose = { (deliveredUnits: Double?) -> DoseEntry in
            let startDate = self.fixtureDate("2018-07-16 03:49:00 +0000")
            let endDate = startDate.addingTimeInterval(TimeInterval(minutes: 5))

            let tempBasalRate = 1.0

            return DoseEntry(
                type: .tempBasal,
                startDate: startDate,
                endDate: endDate,
                value: tempBasalRate,
                unit: .unitsPerHour,
                deliveredUnits: deliveredUnits)
        }

        XCTAssertEqual(0.1, makeDose(nil).unitsInDeliverableIncrements, accuracy: .ulpOfOne)
        XCTAssertEqual(0.05, makeDose(0.05).unitsInDeliverableIncrements, accuracy: .ulpOfOne)
    }

    func testDoseEntryAnnotateShouldSplitDosesProportionally() {
        let startDate = self.fixtureDate("2018-07-16 11:59:00 +0000")
        let endDate = startDate.addingTimeInterval(TimeInterval(minutes: 5))

        let tempBasalRate = 1.0

        let dose = DoseEntry(
            type: .tempBasal,
            startDate: startDate,
            endDate: endDate,
            value: tempBasalRate,
            unit: .unitsPerHour,
            deliveredUnits: 0.1
        )

        let delivery = dose.unitsInDeliverableIncrements

        let basals = loadBasalRateScheduleFixture("basal")

        let splitDoses = [dose].annotated(with: basals)

        XCTAssertEqual(2, splitDoses.count)

        // A 5 minute dose starting one minute before midnight, split at midnight, means split should be 1/5, 4/5
        XCTAssertEqual(delivery * 1.0/5.0, splitDoses[0].unitsInDeliverableIncrements, accuracy: .ulpOfOne)
        XCTAssertEqual(delivery * 4.0/5.0, splitDoses[1].unitsInDeliverableIncrements, accuracy: .ulpOfOne)
    }

    func testDoseEntryWithoutDeliveredUnitsShouldSplitDosesProportionally() {
        let startDate = self.fixtureDate("2018-07-16 11:59:00 +0000")
        let endDate = startDate.addingTimeInterval(TimeInterval(minutes: 5))

        let tempBasalRate = 1.0

        let dose = DoseEntry(
            type: .tempBasal,
            startDate: startDate,
            endDate: endDate,
            value: tempBasalRate,
            unit: .unitsPerHour,
            deliveredUnits: 0.05
        )

        let delivery = dose.unitsInDeliverableIncrements

        let basals = loadBasalRateScheduleFixture("basal")

        let splitDoses = [dose].annotated(with: basals)

        XCTAssertEqual(2, splitDoses.count)

        // A 5 minute dose starting one minute before midnight, split at midnight, means split should be 1/5, 4/5
        XCTAssertEqual(delivery * 1.0/5.0, splitDoses[0].unitsInDeliverableIncrements, accuracy: .ulpOfOne)
        XCTAssertEqual(delivery * 4.0/5.0, splitDoses[1].unitsInDeliverableIncrements, accuracy: .ulpOfOne)
    }

}
