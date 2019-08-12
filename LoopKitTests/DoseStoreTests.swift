//
//  DoseStoreTests.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import XCTest
import CoreData
import HealthKit
@testable import LoopKit

class DoseStoreTests: PersistenceControllerTestCase {

    func testPumpEventTypeDoseMigration() {
        cacheStore.managedObjectContext.performAndWait {
            let event = PumpEvent(entity: PumpEvent.entity(), insertInto: cacheStore.managedObjectContext)

            event.date = Date()
            event.duration = .minutes(30)
            event.unit = .unitsPerHour
            event.type = .tempBasal
            event.value = 0.5
            event.doseType = nil

            XCTAssertNotNil(event.dose)
            XCTAssertEqual(.tempBasal, event.dose!.type)
        }
    }

    func testDeduplication() {
        cacheStore.managedObjectContext.performAndWait {
            let bolus1 = PumpEvent(context: cacheStore.managedObjectContext)

            bolus1.date = DateFormatter.descriptionFormatter.date(from: "2018-04-30 02:12:42 +0000")
            bolus1.raw = Data(hexadecimalString: "0100a600a6001b006a0c335d12")!
            bolus1.type = PumpEventType.bolus
            bolus1.dose = DoseEntry(type: .bolus, startDate: bolus1.date!, value: 4.15, unit: .units, syncIdentifier: bolus1.raw?.hexadecimalString)

            let bolus2 = PumpEvent(context: cacheStore.managedObjectContext)

            bolus2.date = DateFormatter.descriptionFormatter.date(from: "2018-04-30 00:00:00 +0000")
            bolus2.raw = Data(hexadecimalString: "0100a600a6001b006a0c335d12")!
            bolus2.type = PumpEventType.bolus
            bolus2.dose = DoseEntry(type: .bolus, startDate: bolus2.date!, value: 0.15, unit: .units, syncIdentifier: bolus1.raw?.hexadecimalString)

            let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
            let eventsBeforeSave = try! cacheStore.managedObjectContext.fetch(request)
            XCTAssertEqual(2, eventsBeforeSave.count)

            try! cacheStore.managedObjectContext.save()

            let eventsAfterSave = try! cacheStore.managedObjectContext.fetch(request)
            XCTAssertEqual(1, eventsAfterSave.count)
        }
    }

    /// See https://github.com/LoopKit/Loop/issues/853
    func testOutOfOrderDosesSyncedToHealth() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        // 1. Create a DoseStore
        let healthStore = HKHealthStoreMock()

        let doseStore = DoseStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModel: WalshInsulinModel(actionDuration: .hours(4)),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,

            // Set the current date
            test_currentDate: f("2018-12-12 18:07:14 +0000")
        )


        // 2. Add a temp basal which has already ended. It should be saved to Health
        let pumpEvents1 = [
            NewPumpEvent(date: f("2018-12-12 17:35:58 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 2.125, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 58 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-12-12 17:35:58 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 17:35:58 +0000"), endDate: f("2018-12-12 18:05:58 +0000"), value: 2.125, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "1601fa23094c12")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 58 isLeapMonth: false )", type: .tempBasal)
        ]

        doseStore.insulinDeliveryStore.test_lastBasalEndDate = f("2018-12-12 17:35:58 +0000")

        let addPumpEvents1 = expectation(description: "add pumpEvents1")
        addPumpEvents1.expectedFulfillmentCount = 3
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)
            let sample = objects.first as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, sample.insulinDeliveryReason)
            XCTAssertNil(error)
            addPumpEvents1.fulfill()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            addPumpEvents1.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents1.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:58 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)


        // 3. Add a bolus a little later, which started before the last temp basal ends, but wasn't written to pump history until it completed (x22 pump behavior)
        // Even though it is before lastBasalEndDate, it should be saved to HealthKit.
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:16:23 +0000")

        let pumpEvents2 = [
            NewPumpEvent(date: f("2018-12-12 18:05:14 +0000"), dose: DoseEntry(type: .bolus, startDate: f("2018-12-12 18:05:14 +0000"), endDate: f("2018-12-12 18:05:14 +0000"), value: 5.0, unit: .units), isMutable: false, raw: Data(hexadecimalString: "01323200ce052a0c12")!, title: "BolusNormalPumpEvent(length: 9, rawData: 9 bytes, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 5 second: 14 isLeapMonth: false , unabsorbedInsulinRecord: nil, amount: 5.0, programmed: 5.0, unabsorbedInsulinTotal: 0.0, type: MinimedKit.BolusNormalPumpEvent.BolusType.normal, duration: 0.0, deliveryUnitsPerMinute: 1.5)", type: .bolus)
        ]

        let addPumpEvents2 = expectation(description: "add pumpEvents2")
        addPumpEvents2.expectedFulfillmentCount = 3
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)
            let sample = objects.first as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.bolus, sample.insulinDeliveryReason)
            XCTAssertEqual(5.0, sample.quantity.doubleValue(for: .internationalUnit()))
            XCTAssertEqual(f("2018-12-12 18:05:14 +0000"), sample.startDate)
            XCTAssertNil(error)
            addPumpEvents2.fulfill()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            addPumpEvents2.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents2, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents2.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:58 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)


        // Add the next set of pump events, which haven't completed and shouldn't be saved to HealthKit
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:21:22 +0000")

        let pumpEvents3 = [
            NewPumpEvent(date: f("2018-12-12 18:16:31 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0.0, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 16 second: 31 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-12-12 18:16:31 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 18:16:31 +0000"), endDate: f("2018-12-12 18:46:31 +0000"), value: 0.0, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "1601df100a4c12")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 16 second: 31 isLeapMonth: false )", type: .tempBasal),
        ]

        let addPumpEvents3 = expectation(description: "add pumpEvents3")
        addPumpEvents3.expectedFulfillmentCount = 1
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            XCTFail()
        }
        doseStore.addPumpEvents(pumpEvents3, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents3.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:58 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
    }

    /// https://github.com/LoopKit/Loop/issues/852
    func testSplitBasalsSyncedToHealth() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        // Create a DoseStore
        let healthStore = HKHealthStoreMock()

        let doseStore = DoseStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModel: WalshInsulinModel(actionDuration: .hours(4)),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,

            // Set the current date (5 minutes later)
            test_currentDate: f("2018-11-29 11:04:27 +0000")
        )
        doseStore.pumpRecordsBasalProfileStartEvents = false

        doseStore.insulinDeliveryStore.test_lastBasalEndDate = f("2018-11-29 10:54:28 +0000")

        // Add a temp basal. It hasn't finished yet, and should not be saved to Health
        let pumpEvents1 = [
            NewPumpEvent(date: f("2018-11-29 10:59:28 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0.3, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 2 minute: 59 second: 28 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-11-29 10:59:28 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 10:59:28 +0000"), endDate: f("2018-11-29 11:29:28 +0000"), value: 0.3, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "5bffc7cace53e48e87f7cfcb")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 2 minute: 59 second: 28 isLeapMonth: false )", type: .tempBasal)
        ]

        let addPumpEvents1 = expectation(description: "add pumpEvents1")
        addPumpEvents1.expectedFulfillmentCount = 1
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            XCTFail()
        }
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents1.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 10:54:28 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
        XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), doseStore.pumpEventQueryAfterDate)

        // Add the next query of the same pump events (no new data) 5 minutes later. Expect the same result
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:09:27 +0000")

        let addPumpEvents2 = expectation(description: "add pumpEvents2")
        addPumpEvents2.expectedFulfillmentCount = 1
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            XCTFail()
        }
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents2.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 10:54:28 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
        XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), doseStore.pumpEventQueryAfterDate)

        // Add the next set of pump events, including the last temp basal change.
        // The previous, completed basal entries should be saved to Health
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:14:28 +0000")

        let pumpEvents3 = [
            NewPumpEvent(date: f("2018-11-29 11:09:27 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0.325, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 9 second: 27 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-11-29 11:09:27 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 11:09:27 +0000"), endDate: f("2018-11-29 11:39:27 +0000"), value: 0.325, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "5bffca22ce53e48e87f7d624")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 9 second: 27 isLeapMonth: false )", type: .tempBasal)
        ]

        let addPumpEvents3 = expectation(description: "add pumpEvents3")
        addPumpEvents3.expectedFulfillmentCount = 3
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(3, objects.count)
            let basal = objects[0] as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, basal.insulinDeliveryReason)
            XCTAssertEqual(f("2018-11-29 10:54:28 +0000"), basal.startDate)
            XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), basal.endDate)
            XCTAssertEqual("BasalRateSchedule 2018-11-29T10:54:28Z 2018-11-29T10:59:28Z", basal.metadata![HKMetadataKeySyncIdentifier] as! String)
            let temp1 = objects[1] as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, temp1.insulinDeliveryReason)
            XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), temp1.startDate)
            XCTAssertEqual(f("2018-11-29 11:00:00 +0000"), temp1.endDate)
            XCTAssertEqual("5bffc7cace53e48e87f7cfcb 1/2", temp1.metadata![HKMetadataKeySyncIdentifier] as! String)
            XCTAssertEqual(0.003, temp1.quantity.doubleValue(for: .internationalUnit()), accuracy: 0.01)
            let temp2 = objects[2] as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, temp2.insulinDeliveryReason)
            XCTAssertEqual(f("2018-11-29 11:00:00 +0000"), temp2.startDate)
            XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), temp2.endDate)
            XCTAssertEqual("5bffc7cace53e48e87f7cfcb 2/2", temp2.metadata![HKMetadataKeySyncIdentifier] as! String)
            XCTAssertEqual(0.047, temp2.quantity.doubleValue(for: .internationalUnit()), accuracy: 0.01)
            XCTAssertNil(error)
            addPumpEvents3.fulfill()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            addPumpEvents3.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents3, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents3.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
        XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), doseStore.pumpEventQueryAfterDate)

        // Add the next set of pump events, including the last temp basal cancel
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:19:28 +0000")

        let pumpEvents4 = [
            NewPumpEvent(date: f("2018-11-29 11:14:28 +0000"), dose: nil, isMutable: false, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 14 second: 28 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-11-29 11:14:28 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 11:14:28 +0000"), endDate: f("2018-11-29 11:14:28 +0000"), value: 0.0, unit: .unitsPerHour), isMutable: false, raw: Data(hexadecimalString: "5bffced1ce53e48e87f7e33b")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 14 second: 28 isLeapMonth: false )", type: .tempBasal)
        ]

        let addPumpEvents4 = expectation(description: "add pumpEvents4")
        addPumpEvents4.expectedFulfillmentCount = 3
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)
            let temp = objects[0] as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, temp.insulinDeliveryReason)
            XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), temp.startDate)
            XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), temp.endDate)
            XCTAssertEqual("5bffca22ce53e48e87f7d624", temp.metadata![HKMetadataKeySyncIdentifier] as! String)
            XCTAssertEqual(0.05, temp.quantity.doubleValue(for: .internationalUnit()), accuracy: 0.01)
            XCTAssertNil(error)
            addPumpEvents4.fulfill()
        })
        doseStore.insulinDeliveryStore.test_lastBasalEndDateDidSet = {
            addPumpEvents4.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents4, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents4.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), doseStore.pumpEventQueryAfterDate)
        XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), doseStore.insulinDeliveryStore.test_lastBasalEndDate)
    }
}
