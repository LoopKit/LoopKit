//
//  MockKitTests.swift
//  MockKitTests
//
//  Created by Nathaniel Hamming on 2020-11-27.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import LoopKit
@testable import MockKit

class UnfinalizedDoseTests: XCTestCase {

    func testInitializationBolus() {
        let amount = 3.5
        let startTime = Date()
        let duration = TimeInterval(5)
        let unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: startTime,
                                               duration: duration,
                                               insulinType: nil,
                                               automatic: false)
        XCTAssertEqual(unfinalizedBolus.doseType, .bolus)
        XCTAssertEqual(unfinalizedBolus.units, amount)
        XCTAssertNil(unfinalizedBolus.scheduledUnits)
        XCTAssertNil(unfinalizedBolus.scheduledTempRate)
        XCTAssertEqual(unfinalizedBolus.startTime, startTime)
        XCTAssertEqual(unfinalizedBolus.duration, duration)
        XCTAssertEqual(unfinalizedBolus.finishTime, startTime.addingTimeInterval(duration))
        XCTAssertEqual(unfinalizedBolus.rate, amount/duration.hours)
        XCTAssertNil(unfinalizedBolus.insulinType)
        XCTAssertEqual(unfinalizedBolus.automatic, false)
    }

    func testInitializationTBR() {
        let amount = 0.5
        let startTime = Date()
        let duration = TimeInterval.minutes(30)
        let unfinalizedTBR = UnfinalizedDose(tempBasalRate: amount,
                                             startTime: startTime,
                                             duration: duration,
                                             automatic: true)
        XCTAssertEqual(unfinalizedTBR.doseType, .tempBasal)
        XCTAssertEqual(unfinalizedTBR.units, amount*duration.hours)
        XCTAssertNil(unfinalizedTBR.scheduledUnits)
        XCTAssertNil(unfinalizedTBR.scheduledTempRate)
        XCTAssertEqual(unfinalizedTBR.startTime, startTime)
        XCTAssertEqual(unfinalizedTBR.duration, duration)
        XCTAssertEqual(unfinalizedTBR.finishTime, startTime.addingTimeInterval(duration))
        XCTAssertEqual(unfinalizedTBR.rate, amount)
        XCTAssertEqual(unfinalizedTBR.automatic, true)
    }

    func testInitializatinSuspend() {
        let startTime = Date()
        let unfinalizedSuspend = UnfinalizedDose(suspendStartTime: startTime)
        XCTAssertEqual(unfinalizedSuspend.doseType, .suspend)
        XCTAssertEqual(unfinalizedSuspend.units, 0)
        XCTAssertNil(unfinalizedSuspend.scheduledUnits)
        XCTAssertNil(unfinalizedSuspend.scheduledTempRate)
        XCTAssertEqual(unfinalizedSuspend.startTime, startTime)
        XCTAssertEqual(unfinalizedSuspend.rate, 0)
    }

    func testInitializationResume() {
        let startTime = Date()
        let unfinalizedResume = UnfinalizedDose(resumeStartTime: startTime)
        XCTAssertEqual(unfinalizedResume.doseType, .resume)
        XCTAssertEqual(unfinalizedResume.units, 0)
        XCTAssertNil(unfinalizedResume.scheduledUnits)
        XCTAssertNil(unfinalizedResume.scheduledTempRate)
        XCTAssertEqual(unfinalizedResume.startTime, startTime)
        XCTAssertEqual(unfinalizedResume.rate, 0)
    }

    func testIsFinished() {
        let amount = 0.5
        let now = Date()
        let duration = TimeInterval.minutes(30)
        var unfinalizedTBR = UnfinalizedDose(tempBasalRate: amount,
                                             startTime: now,
                                             duration: duration,
                                             automatic: true)
        XCTAssertFalse(unfinalizedTBR.finished)

        unfinalizedTBR = UnfinalizedDose(tempBasalRate: amount,
                                         startTime: now-duration,
                                         duration: duration,
                                         automatic: true)
        XCTAssertTrue(unfinalizedTBR.finished)
    }

    func testFinalizedUnits() {
        let amount = 3.5
        let now = Date()
        let duration = TimeInterval.minutes(1)
        var unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: now,
                                               duration: duration,
                                               automatic: true)
        XCTAssertNil(unfinalizedBolus.finalizedUnits)

        unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                           startTime: now-duration,
                                           duration: duration,
                                           automatic: true)
        XCTAssertEqual(unfinalizedBolus.finalizedUnits, amount)
    }

    func testCancel() {
        let now = Date()
        let rate = 3.0
        let duration = TimeInterval.hours(1)
        var dose = UnfinalizedDose(tempBasalRate: rate,
                                   startTime: now,
                                   duration: duration,
                                   automatic: true)
        dose.cancel(at: now + duration/2)

        XCTAssertEqual(dose.units, rate/2)
        XCTAssertEqual(dose.scheduledUnits, rate)
        XCTAssertEqual(dose.scheduledTempRate, rate)
        XCTAssertEqual(dose.duration, duration/2)
        XCTAssertEqual(dose.automatic, true)
    }

    func testRawValue() {
        let amount = 3.5
        let startTime = Date()
        let duration = TimeInterval.minutes(1)
        let unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: startTime,
                                               duration: duration,
                                               automatic: true)
        let rawValue = unfinalizedBolus.rawValue
        XCTAssertEqual(UnfinalizedDose.DoseType(rawValue: rawValue["doseType"] as! UnfinalizedDose.DoseType.RawValue), .bolus)
        XCTAssertEqual(rawValue["units"] as! Double, amount)
        XCTAssertEqual(rawValue["startTime"] as! Date, startTime)
        XCTAssertNil(rawValue["scheduledUnits"])
        XCTAssertNil(rawValue["scheduledTempRate"])
        XCTAssertEqual(rawValue["duration"] as! Double, duration)
        XCTAssertEqual(rawValue["automatic"] as! Bool, true)
    }

    func testRawValueBolusWithScheduledUnits() {
        let amount = 3.5
        let startTime = Date()
        let duration = TimeInterval.minutes(1)
        var unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: startTime,
                                               duration: duration,
                                               automatic: true)
        unfinalizedBolus.scheduledUnits = amount
        let rawValue = unfinalizedBolus.rawValue
        XCTAssertEqual(UnfinalizedDose.DoseType(rawValue: rawValue["doseType"] as! UnfinalizedDose.DoseType.RawValue), .bolus)
        XCTAssertEqual(rawValue["units"] as! Double, amount)
        XCTAssertEqual(rawValue["startTime"] as! Date, startTime)
        XCTAssertEqual(rawValue["scheduledUnits"] as! Double, amount)
        XCTAssertNil(rawValue["scheduleTempRate"])
        XCTAssertEqual(rawValue["duration"] as! Double, duration)
        XCTAssertEqual(rawValue["automatic"] as! Bool, true)

        let restoredUnfinalizedBolus = UnfinalizedDose(rawValue: rawValue)!
        XCTAssertEqual(restoredUnfinalizedBolus.doseType, unfinalizedBolus.doseType)
        XCTAssertEqual(restoredUnfinalizedBolus.units, unfinalizedBolus.units)
        XCTAssertEqual(restoredUnfinalizedBolus.scheduledUnits, unfinalizedBolus.scheduledUnits)
        XCTAssertEqual(restoredUnfinalizedBolus.scheduledTempRate, unfinalizedBolus.scheduledTempRate)
        XCTAssertEqual(restoredUnfinalizedBolus.startTime, unfinalizedBolus.startTime)
        XCTAssertEqual(restoredUnfinalizedBolus.duration, unfinalizedBolus.duration)
        XCTAssertEqual(restoredUnfinalizedBolus.automatic, unfinalizedBolus.automatic)
        XCTAssertEqual(restoredUnfinalizedBolus.finishTime, unfinalizedBolus.finishTime)
        XCTAssertEqual(restoredUnfinalizedBolus.rate, unfinalizedBolus.rate)
    }

    func testRawValueTBRWithScheduledTempRate() {
        let rate = 0.5
        let startTime = Date()
        let duration = TimeInterval.minutes(30)
        var unfinalizedTBR = UnfinalizedDose(tempBasalRate: rate,
                                             startTime: startTime,
                                             duration: duration,
                                             automatic: true)
        unfinalizedTBR.scheduledTempRate = rate
        let rawValue = unfinalizedTBR.rawValue
        XCTAssertEqual(UnfinalizedDose.DoseType(rawValue: rawValue["doseType"] as! UnfinalizedDose.DoseType.RawValue), .tempBasal)
        XCTAssertEqual(rawValue["units"] as! Double, rate*duration.hours)
        XCTAssertEqual(rawValue["startTime"] as! Date, startTime)
        XCTAssertNil(rawValue["scheduledUnits"])
        XCTAssertEqual(rawValue["scheduledTempRate"] as! Double, rate)
        XCTAssertEqual(rawValue["duration"] as! Double, duration)
        XCTAssertEqual(rawValue["automatic"] as! Bool, true)

        let restoredUnfinalizedTBR = UnfinalizedDose(rawValue: rawValue)!
        XCTAssertEqual(restoredUnfinalizedTBR.doseType, unfinalizedTBR.doseType)
        XCTAssertEqual(restoredUnfinalizedTBR.units, unfinalizedTBR.units)
        XCTAssertEqual(restoredUnfinalizedTBR.scheduledUnits, unfinalizedTBR.scheduledUnits)
        XCTAssertEqual(restoredUnfinalizedTBR.scheduledTempRate, unfinalizedTBR.scheduledTempRate)
        XCTAssertEqual(restoredUnfinalizedTBR.startTime, unfinalizedTBR.startTime)
        XCTAssertEqual(restoredUnfinalizedTBR.duration, unfinalizedTBR.duration)
        XCTAssertEqual(restoredUnfinalizedTBR.automatic, unfinalizedTBR.automatic)
        XCTAssertEqual(restoredUnfinalizedTBR.finishTime, unfinalizedTBR.finishTime)
        XCTAssertEqual(restoredUnfinalizedTBR.rate, unfinalizedTBR.rate)
    }

    func testRestoreFromRawValue() {
        let rate = 0.5
        let startTime = Date()
        let duration = TimeInterval.minutes(30)
        let expectedUnfinalizedTBR = UnfinalizedDose(tempBasalRate: rate,
                                                     startTime: startTime,
                                                     duration: duration,
                                                     automatic: true)
        let rawValue = expectedUnfinalizedTBR.rawValue
        let unfinalizedTBR = UnfinalizedDose(rawValue: rawValue)!
        XCTAssertEqual(unfinalizedTBR.doseType, .tempBasal)
        XCTAssertEqual(unfinalizedTBR.units, rate*duration.hours)
        XCTAssertNil(unfinalizedTBR.scheduledUnits)
        XCTAssertNil(unfinalizedTBR.scheduledTempRate)
        XCTAssertEqual(unfinalizedTBR.startTime, startTime)
        XCTAssertEqual(unfinalizedTBR.duration, duration)
        XCTAssertEqual(unfinalizedTBR.automatic, true)
        XCTAssertEqual(unfinalizedTBR.finishTime, startTime.addingTimeInterval(duration))
        XCTAssertEqual(unfinalizedTBR.rate, rate)
    }

    func testDoseEntryInitFromUnfinalizedBolus() {
        let amount = 3.5
        let now = Date()
        let duration = TimeInterval.minutes(1)
        let unfinalizedBolus = UnfinalizedDose(bolusAmount: amount,
                                               startTime: now,
                                               duration: duration,
                                               automatic: true)
        let doseEntry = DoseEntry(unfinalizedBolus)
        XCTAssertEqual(doseEntry.type, .bolus)
        XCTAssertEqual(doseEntry.startDate, now)
        XCTAssertEqual(doseEntry.endDate, now.addingTimeInterval(duration))
        XCTAssertEqual(doseEntry.programmedUnits, amount)
        XCTAssertEqual(doseEntry.unit, .units)
        XCTAssertEqual(doseEntry.automatic, true)
        XCTAssertNil(doseEntry.deliveredUnits)
    }

    func testDoseEntryInitFromUnfinalizedTBR() {
        let amount = 0.5
        let now = Date()
        let duration = TimeInterval.minutes(30)
        let rate = amount*duration.hours
        let unfinalizedTBR = UnfinalizedDose(tempBasalRate: amount,
                                             startTime: now,
                                             duration: duration,
                                             automatic: true)
        let doseEntry = DoseEntry(unfinalizedTBR)
        XCTAssertEqual(doseEntry.type, .tempBasal)
        XCTAssertEqual(doseEntry.startDate, now)
        XCTAssertEqual(doseEntry.endDate, now.addingTimeInterval(duration))
        XCTAssertEqual(doseEntry.programmedUnits, rate)
        XCTAssertEqual(doseEntry.unit, .unitsPerHour)
        XCTAssertEqual(doseEntry.automatic, true)
        XCTAssertNil(doseEntry.deliveredUnits)
    }

    func testDoseEntryInitFromUnfinalizedSuspend() {
        let now = Date()
        let unfinalizedSuspend = UnfinalizedDose(suspendStartTime: now)
        let doseEntry = DoseEntry(unfinalizedSuspend)
        XCTAssertEqual(doseEntry.type, .suspend)
        XCTAssertEqual(doseEntry.startDate, now)
        XCTAssertEqual(doseEntry.endDate, now)
        XCTAssertEqual(doseEntry.programmedUnits, 0)
        XCTAssertEqual(doseEntry.unit, .units)
        XCTAssertNil(doseEntry.deliveredUnits)
    }

    func testDoseEntryInitFromUnfinalizedResume() {
        let now = Date()
        let unfinalizedResume = UnfinalizedDose(resumeStartTime: now)
        let doseEntry = DoseEntry(unfinalizedResume)
        XCTAssertEqual(doseEntry.type, .resume)
        XCTAssertEqual(doseEntry.startDate, now)
        XCTAssertEqual(doseEntry.endDate, now)
        XCTAssertEqual(doseEntry.programmedUnits, 0)
        XCTAssertEqual(doseEntry.unit, .units)
        XCTAssertNil(doseEntry.deliveredUnits)
    }

    func testBolusCancelLongAfterFinishTime() {
        let end = Date()
        let duration = TimeInterval(1)
        var dose = UnfinalizedDose(bolusAmount: 1, startTime: end-duration, duration: duration, automatic: false)
        dose.cancel(at: end + .hours(1))

        XCTAssertEqual(1.0, dose.units)
        XCTAssertTrue(dose.finished)
    }

    func testInterruptedBolus() {
        let end = Date()
        let duration = TimeInterval.minutes(1)
        var dose = UnfinalizedDose(bolusAmount: 5,
                                   startTime: end - duration/2,
                                   duration: duration,
                                   automatic: false)
        dose.cancel(at: end)

        XCTAssertEqual(dose.units, 2.5)
        XCTAssertEqual(dose.scheduledUnits, 5)
        XCTAssertEqual(dose.duration, TimeInterval.minutes(0.5))
        XCTAssertEqual(dose.finishTime, end)
        XCTAssertTrue(dose.finished)
        XCTAssertEqual(dose.progress, 1)
        XCTAssertEqual(dose.finalizedUnits!, 2.5)
        XCTAssertEqual(dose.automatic, false)
        XCTAssertTrue(dose.description.contains("Interrupted Bolus"))

        let doseEntry = DoseEntry(dose)
        XCTAssertEqual(doseEntry.deliveredUnits, 2.5)
        XCTAssertEqual(doseEntry.programmedUnits, 5)
        XCTAssertEqual(doseEntry.startDate, end - duration/2)
        XCTAssertEqual(doseEntry.endDate, end)
        XCTAssertEqual(doseEntry.type, .bolus)
        XCTAssertEqual(doseEntry.automatic, false)
    }
}
