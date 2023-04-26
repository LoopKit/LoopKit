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

    func loadReservoirFixture(_ resourceName: String) -> [NewReservoirValue] {

        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate(timeZone: .utcTimeZone)

        return fixture.map {
            return NewReservoirValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, unitVolume: $0["amount"] as! Double)
        }
    }

    func defaultStore(testingDate: Date? = nil) -> DoseStore {
        let healthStore = HKHealthStoreMock()
        let doseStore = DoseStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(WalshInsulinModel(actionDuration: .hours(4))),
            longestEffectDuration: .hours(4),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,
            provenanceIdentifier: Bundle.main.bundleIdentifier!,
            test_currentDate: testingDate
        )

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            semaphore.signal()
        }
        semaphore.wait()

        return doseStore
    }

    let testingDateFormatter = DateFormatter.descriptionFormatter

    func testingDate(_ input: String) -> Date {
        return testingDateFormatter.date(from: input)!
    }

    func testEmptyDoseStoreReturnsZeroInsulinOnBoard() {
        let doseStore = defaultStore()

        let queryFinishedExpectation = expectation(description: "query finished")
        
        doseStore.insulinOnBoard(at: Date()) { (result) in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success(let value):
                XCTAssertEqual(0, value.value)
            }
            queryFinishedExpectation.fulfill()
        }
        waitForExpectations(timeout: 3)
    }

    func testGetNormalizedDoseEntriesUsingReservoir() {
        let now = testingDate("2022-09-05 02:04:00 +0000")
        let doseStore = defaultStore(testingDate: now)

        let reservoirReadings = loadReservoirFixture("reservoir_iob_test")

        let storageExpectations = expectation(description: "reservoir store finished")
        storageExpectations.expectedFulfillmentCount = reservoirReadings.count + 1
        for reading in reservoirReadings.reversed() {
            doseStore.addReservoirValue(reading.unitVolume, at: reading.startDate) { _, _, _, _ in storageExpectations.fulfill() }
        }

        let bolusStart = testingDate("2022-09-05 01:49:47 +0000")
        let bolusEnd = testingDate("2022-09-05 01:51:19 +0000")
        let bolus = DoseEntry(type: .bolus, startDate: bolusStart, endDate: bolusEnd, value: 2.3, unit: .units, isMutable: true)
        let pumpEvent = NewPumpEvent(date: bolus.startDate, dose: bolus, raw: Data(hexadecimalString: "0000")!, title: "Bolus 2.3U")

        doseStore.addPumpEvents([pumpEvent], lastReconciliation: testingDate("2022-09-05 01:50:18 +0000")) { error in
            storageExpectations.fulfill()
        }
        
        waitForExpectations(timeout: 2)

        let queryFinishedExpectation = expectation(description: "query finished")

        doseStore.insulinOnBoard(at: now) { (result) in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success(let value):
                XCTAssertEqual(2.25, value.value, accuracy: 0.01)
            }
            queryFinishedExpectation.fulfill()
        }
        waitForExpectations(timeout: 3)
    }

    func testMutableDosesIncludedInIOB() {
        let now = testingDate("2023-01-08 17:11:14 +0000")
        let doseStore = defaultStore(testingDate: now)

        let reservoirReadings = loadReservoirFixture("reservoir_for_iob_missing")

        let storageExpectations = expectation(description: "reservoir store finished")
        storageExpectations.expectedFulfillmentCount = reservoirReadings.count + 1
        for reading in reservoirReadings.reversed() {
            doseStore.addReservoirValue(reading.unitVolume, at: reading.startDate) { _, _, _, _ in storageExpectations.fulfill() }
        }

        let lastReconciliation = testingDate("2023-01-08 17:08:27 +0000")

        // NewPumpEvent(date: 2023-01-08 17:04:58 +0000, dose: Optional(LoopKit.DoseEntry(type: LoopKit.DoseType.bolus, startDate: 2023-01-08 17:04:58 +0000, endDate: 2023-01-08 17:08:24 +0000, value: 5.15, unit: LoopKit.DoseUnit.units, deliveredUnits: Optional(5.15), description: nil, insulinType: Optional(LoopKit.InsulinType.novolog), automatic: Optional(false), manuallyEntered: false, syncIdentifier: Optional("464327afd390446786cced682f22448f"), isMutable: true, wasProgrammedByPumpUI: false, scheduledBasalRate: nil)), raw: 16 bytes, type: Optional(LoopKit.PumpEventType.bolus), title: "Bolus", alarmType: nil),

        // NewPumpEvent(date: 2023-01-08 17:02:35 +0000, dose: Optional(LoopKit.DoseEntry(type: LoopKit.DoseType.tempBasal, startDate: 2023-01-08 17:02:35 +0000, endDate: 2023-01-08 17:32:35 +0000, value: 0.575, unit: LoopKit.DoseUnit.unitsPerHour, deliveredUnits: nil, description: nil, insulinType: Optional(LoopKit.InsulinType.novolog), automatic: Optional(true), manuallyEntered: false, syncIdentifier: Optional("61487bd5d34f4ff49a7f0766066e7773"), isMutable: false, wasProgrammedByPumpUI: false, scheduledBasalRate: nil)), raw: 16 bytes, type: Optional(LoopKit.PumpEventType.tempBasal), title: "Temp Basal", alarmType: nil)]

        let bolusStart = testingDate("2023-01-08 17:04:58 +0000")
        let bolusEnd = testingDate("2023-01-08 17:08:24 +0000")
        let bolus = DoseEntry(type: .bolus, startDate: bolusStart, endDate: bolusEnd, value: 5.15, unit: .units, isMutable: true)

        let tempBasalStart = testingDate("2023-01-08 17:02:35 +0000")
        let tempBasalEnd = testingDate("2023-01-08 17:32:35 +0000")
        let tempBasal = DoseEntry(type: .tempBasal, startDate: tempBasalStart, endDate: tempBasalEnd, value:0.575, unit: .unitsPerHour, isMutable: false)

        let pumpEvents: [NewPumpEvent] = [
            NewPumpEvent(date: bolus.startDate, dose: bolus, raw: Data(hexadecimalString: "0000")!, title: "Bolus 5.15U"),
            NewPumpEvent(date: tempBasal.startDate, dose: tempBasal, raw: Data(hexadecimalString: "0001")!, title: "TempBasal 0.575 U/hr")
        ]

        doseStore.addPumpEvents(pumpEvents, lastReconciliation: lastReconciliation) { error in
            storageExpectations.fulfill()
        }

        waitForExpectations(timeout: 2)

        let queryFinishedExpectation = expectation(description: "query finished")

        doseStore.insulinOnBoard(at: now) { (result) in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected error: \(error)")
            case .success(let value):
                XCTAssertEqual(5.07, value.value, accuracy: 0.01)
            }
            queryFinishedExpectation.fulfill()
        }
        waitForExpectations(timeout: 3)
    }

    
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

        let doseStoreInitialization = expectation(description: "Expect DoseStore to finish initialization")

        let doseStore = DoseStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(WalshInsulinModel(actionDuration: .hours(4))),
            longestEffectDuration: .hours(4),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [ // Timezone = -0800
                ["value": 0.75, "startTime": 0.0],       // 0000 - Midnight
                ["value": 0.8, "startTime": 10800.0],    // 0300 - 3am
                ["value": 0.85, "startTime": 32400.0],   // 0900 - 9am
                ["value": 1.0, "startTime": 68400.0]]]), // 1900 - 7pm
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,
            provenanceIdentifier: Bundle.main.bundleIdentifier!,
            onReady: { _ in doseStoreInitialization.fulfill() },

            // Set the current date
            test_currentDate: f("2018-12-12 18:07:14 +0000")
        )

        waitForExpectations(timeout: 3)

        // 2. Add a temp basal which has already ended. It should be saved to Health
        let pumpEvents1 = [
            NewPumpEvent(date: f("2018-12-12 17:35:58 +0000"), dose: nil, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 2.125, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 58 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-12-12 17:35:58 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 17:35:58 +0000"), endDate: f("2018-12-12 18:05:58 +0000"), value: 2.125, unit: .unitsPerHour), raw: Data(hexadecimalString: "1601fa23094c12")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 58 isLeapMonth: false )", type: .tempBasal)
        ]

        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate = f("2018-12-12 17:35:58 +0000")

        let addPumpEvents1 = expectation(description: "add pumpEvents1")
        addPumpEvents1.expectedFulfillmentCount = 2
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)
            let sample = objects.first as! HKQuantitySample
            XCTAssertEqual(HKInsulinDeliveryReason.basal, sample.insulinDeliveryReason)
            XCTAssertNil(error)
            addPumpEvents1.fulfill()
        })
        let lastBasalEndDateSetExpectation = expectation(description: "last basal end date set")
        lastBasalEndDateSetExpectation.assertForOverFulfill = false
        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDateDidSet = {
            lastBasalEndDateSetExpectation.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents1.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:58 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)


        // 3. Add a bolus a little later, which started before the last temp basal ends, but wasn't written to pump history until it completed (x22 pump behavior)
        // Even though it is before lastBasalEndDate, it should be saved to HealthKit.
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:16:23 +0000")

        let pumpEvents2 = [
            NewPumpEvent(date: f("2018-12-12 18:05:14 +0000"), dose: DoseEntry(type: .bolus, startDate: f("2018-12-12 18:05:14 +0000"), endDate: f("2018-12-12 18:05:14 +0000"), value: 5.0, unit: .units), raw: Data(hexadecimalString: "01323200ce052a0c12")!, title: "BolusNormalPumpEvent(length: 9, rawData: 9 bytes, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 5 second: 14 isLeapMonth: false , unabsorbedInsulinRecord: nil, amount: 5.0, programmed: 5.0, unabsorbedInsulinTotal: 0.0, type: MinimedKit.BolusNormalPumpEvent.BolusType.normal, duration: 0.0, deliveryUnitsPerMinute: 1.5)", type: .bolus)
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
        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDateDidSet = {
            addPumpEvents2.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents2, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents2.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:58 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)


        // Add the next set of pump events, which haven't completed and shouldn't be saved to HealthKit
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:21:22 +0000")

        let pumpEvents3 = [
            NewPumpEvent(date: f("2018-12-12 18:16:31 +0000"), dose: nil, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0.0, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 16 second: 31 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-12-12 18:16:31 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 18:16:31 +0000"), endDate: f("2018-12-12 18:46:31 +0000"), value: 0.0, unit: .unitsPerHour), raw: Data(hexadecimalString: "1601df100a4c12")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 16 second: 31 isLeapMonth: false )", type: .tempBasal),
        ]

        let addPumpEvents3 = expectation(description: "add pumpEvents3")
        addPumpEvents3.expectedFulfillmentCount = 1
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDateDidSet = nil
        doseStore.addPumpEvents(pumpEvents3, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents3.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:58 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)
    }

    /// https://github.com/LoopKit/Loop/issues/852
    func testSplitBasalsSyncedToHealth() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        // Create a DoseStore
        let healthStore = HKHealthStoreMock()

        let doseStoreInitialization = expectation(description: "Expect DoseStore to finish initialization")

        let doseStore = DoseStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(WalshInsulinModel(actionDuration: .hours(4))),
            longestEffectDuration: .hours(4),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,
            provenanceIdentifier: Bundle.main.bundleIdentifier!,

            onReady: { _ in doseStoreInitialization.fulfill() },

            // Set the current date (5 minutes later)
            test_currentDate: f("2018-11-29 11:04:27 +0000")
        )

        waitForExpectations(timeout: 3)

        doseStore.pumpRecordsBasalProfileStartEvents = false

        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate = f("2018-11-29 10:54:28 +0000")

        // Add a temp basal. It hasn't finished yet, and should not be saved to Health
        let pumpEvents1 = [
            NewPumpEvent(date: f("2018-11-29 10:59:28 +0000"), dose: nil, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0.3, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 2 minute: 59 second: 28 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-11-29 10:59:28 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 10:59:28 +0000"), endDate: f("2018-11-29 11:29:28 +0000"), value: 0.3, unit: .unitsPerHour), raw: Data(hexadecimalString: "5bffc7cace53e48e87f7cfcb")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 2 minute: 59 second: 28 isLeapMonth: false )", type: .tempBasal)
        ]

        let addPumpEvents1 = expectation(description: "add pumpEvents1")
        addPumpEvents1.expectedFulfillmentCount = 1
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents1.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 10:54:28 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)
        XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), doseStore.pumpEventQueryAfterDate)

        // Add the next query of the same pump events (no new data) 5 minutes later. Expect the same result
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:09:27 +0000")

        let addPumpEvents2 = expectation(description: "add pumpEvents2")
        addPumpEvents2.expectedFulfillmentCount = 1
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDateDidSet = {
            XCTFail()
        }
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents2.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 10:54:28 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)
        XCTAssertEqual(f("2018-11-29 10:59:28 +0000"), doseStore.pumpEventQueryAfterDate)

        // Add the next set of pump events, including the last temp basal change.
        // The previous, completed basal entries should be saved to Health
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:14:28 +0000")

        let pumpEvents3 = [
            NewPumpEvent(date: f("2018-11-29 11:09:27 +0000"), dose: nil, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0.325, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 9 second: 27 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-11-29 11:09:27 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 11:09:27 +0000"), endDate: f("2018-11-29 11:39:27 +0000"), value: 0.325, unit: .unitsPerHour), raw: Data(hexadecimalString: "5bffca22ce53e48e87f7d624")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 9 second: 27 isLeapMonth: false )", type: .tempBasal)
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
        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDateDidSet = {
            addPumpEvents3.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents3, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents3.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)
        XCTAssertEqual(f("2018-11-29 11:09:27 +0000"), doseStore.pumpEventQueryAfterDate)

        // Add the next set of pump events, including the last immutable temp basal cancel
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:19:28 +0000")

        let pumpEvents4 = [
            NewPumpEvent(date: f("2018-11-29 11:14:28 +0000"), dose: nil, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 0, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 14 second: 28 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-11-29 11:14:28 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 11:14:28 +0000"), endDate: f("2018-11-29 11:14:28 +0000"), value: 0.0, unit: .unitsPerHour), raw: Data(hexadecimalString: "5bffced1ce53e48e87f7e33b")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 14 second: 28 isLeapMonth: false )", type: .tempBasal)
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
        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDateDidSet = {
            addPumpEvents4.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents4, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents4.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), doseStore.pumpEventQueryAfterDate)
        XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)

        // Add the final mutable pump event, it should NOT be synced to HealthKit
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-11-29 11:24:28 +0000")

        let pumpEvents5 = [
            NewPumpEvent(date: f("2018-11-29 11:14:28 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-11-29 11:14:28 +0000"), endDate: f("2018-11-29 11:44:28 +0000"), value: 1.0, unit: .unitsPerHour, isMutable: true), raw: Data(hexadecimalString: "e48e87f7e33b5bffced1ce53")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 11 day: 29 hour: 3 minute: 14 second: 28 isLeapMonth: false )", type: .tempBasal)
        ]

        let addPumpEvents5 = expectation(description: "add pumpEvents5")
        addPumpEvents5.expectedFulfillmentCount = 2
        healthStore.setSaveHandler({ (objects, success, error) in
            XCTFail()
        })
        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDateDidSet = {
            addPumpEvents5.fulfill()
        }
        doseStore.addPumpEvents(pumpEvents5, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            addPumpEvents5.fulfill()
        }
        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), doseStore.pumpEventQueryAfterDate)
        XCTAssertEqual(f("2018-11-29 11:14:28 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)
    }

    func testAddPumpEventsProgrammedByPumpUI() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        let doseStoreInitialization = expectation(description: "Expect DoseStore to finish initialization")


        // 1. Create a DoseStore
        let doseStore = DoseStore(
            healthStore: HKHealthStoreMock(),
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(WalshInsulinModel(actionDuration: .hours(4))),
            longestEffectDuration: .hours(4),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 37800.0]]]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,
            provenanceIdentifier: Bundle.main.bundleIdentifier!,

            onReady: { _ in doseStoreInitialization.fulfill() },

            // Set the current date
            test_currentDate: f("2018-12-12 18:07:14 +0000")
        )
        waitForExpectations(timeout: 3)


        // 2. Add a temp basal which has already ended. It should persist in InsulinDeliveryStore.
        let pumpEvents1 = [
            NewPumpEvent(date: f("2018-12-12 17:35:00 +0000"), dose: nil, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 2.125, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 0 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-12-12 17:35:00 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 17:35:00 +0000"), endDate: f("2018-12-12 18:05:00 +0000"), value: 2.125, unit: .unitsPerHour, wasProgrammedByPumpUI: true), raw: Data(hexadecimalString: "1601fa23094c12")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 0 isLeapMonth: false )", type: .tempBasal)
        ]

        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate = f("2018-12-12 17:35:00 +0000")
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:07:14 +0000")

        let addPumpEvents1 = expectation(description: "addPumpEvents1")
        addPumpEvents1.expectedFulfillmentCount = 2
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            doseStore.insulinDeliveryStore.getDoseEntries { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 1)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                }
                addPumpEvents1.fulfill();
            }
            doseStore.insulinDeliveryStore.getDoseEntries(includeMutable: true) { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 1)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                    XCTAssertTrue(doseEntries[0].wasProgrammedByPumpUI)
                }
                addPumpEvents1.fulfill();
            }
        }

        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:00 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)

    }

    func testBasalInsertionBetweenTempBasals() {


        let start = testingDate("2018-12-12 17:00:00 +0000")
        let now = start.addingTimeInterval(.minutes(20))

        let doseStore = defaultStore(testingDate: now)

        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate = start


        // 2. Add a temp basal which has already ended. It should persist in InsulinDeliveryStore.
        let pumpEvents1 = [
            NewPumpEvent(
                date: start,
                dose: DoseEntry(
                    type: .tempBasal,
                    startDate: start,
                    endDate: start.addingTimeInterval(.minutes(5)),
                    value: 1.5,
                    unit: .unitsPerHour,
                    automatic: true),
                raw: Data(hexadecimalString: "01")!,
                title: "First Temp",
                type: .tempBasal),
            NewPumpEvent(
                date: start.addingTimeInterval(.minutes(10)),
                dose: DoseEntry(
                    type: .tempBasal,
                    startDate: start.addingTimeInterval(.minutes(10)),
                    endDate: start.addingTimeInterval(.minutes(15)),
                    value: 1.5,
                    unit: .unitsPerHour,
                    automatic: true),
                raw: Data(hexadecimalString: "02")!,
                title: "Second Temp",
                type: .tempBasal)
        ]

        let addPumpEvents = expectation(description: "addPumpEvents")
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: now) { (error) in
            XCTAssertNil(error)
            doseStore.insulinDeliveryStore.getDoseEntries(start: start, end: start.addingTimeInterval(.minutes(20))) { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 3)
                    XCTAssertTrue(doseEntries[0].automatic!)
                    XCTAssertTrue(doseEntries[1].automatic!)
                    XCTAssertTrue(doseEntries[2].automatic!)
                }
                addPumpEvents.fulfill();
            }
        }

        waitForExpectations(timeout: 3)

    }

    func testAddPumpEventsPurgesMutableDosesFromInsulinDeliveryStore() {
        let formatter = DateFormatter.descriptionFormatter
        let f = { (input) in
            return formatter.date(from: input)!
        }

        let doseStoreInitialization = expectation(description: "Expect DoseStore to finish initialization")


        // 1. Create a DoseStore
        let doseStore = DoseStore(
            healthStore: HKHealthStoreMock(),
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(WalshInsulinModel(actionDuration: .hours(4))),
            longestEffectDuration: .hours(4),
            basalProfile: BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 37800.0]]]),
            insulinSensitivitySchedule: InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]]),
            syncVersion: 1,
            provenanceIdentifier: Bundle.main.bundleIdentifier!,

            onReady: { _ in doseStoreInitialization.fulfill() },
            // Set the current date
            test_currentDate: f("2018-12-12 18:07:14 +0000")
        )

        waitForExpectations(timeout: 3)

        // 2. Add a temp basal which has already ended. It should persist in InsulinDeliveryStore.
        let pumpEvents1 = [
            NewPumpEvent(date: f("2018-12-12 17:35:00 +0000"), dose: nil, raw: UUID().data, title: "TempBasalPumpEvent(length: 8, rawData: 8 bytes, rateType: MinimedKit.TempBasalPumpEvent.RateType.Absolute, rate: 2.125, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 0 isLeapMonth: false )", type: nil),
            NewPumpEvent(date: f("2018-12-12 17:35:00 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 17:35:00 +0000"), endDate: f("2018-12-12 18:05:00 +0000"), value: 2.125, unit: .unitsPerHour), raw: Data(hexadecimalString: "1601fa23094c12")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 9 minute: 35 second: 0 isLeapMonth: false )", type: .tempBasal)
        ]

        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate = f("2018-12-12 17:35:00 +0000")
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:07:14 +0000")

        let addPumpEvents1 = expectation(description: "addPumpEvents1")
        addPumpEvents1.expectedFulfillmentCount = 2
        doseStore.addPumpEvents(pumpEvents1, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            doseStore.insulinDeliveryStore.getDoseEntries { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 1)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                }
                addPumpEvents1.fulfill();
            }
            doseStore.insulinDeliveryStore.getDoseEntries(includeMutable: true) { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 1)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                }
                addPumpEvents1.fulfill();
            }
        }

        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:00 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)

        // 3. Add a mutable temp basal. It should persist in InsulinDeliveryStore.
        let pumpEvents2 = [
            NewPumpEvent(date: f("2018-12-12 18:05:00 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 18:05:00 +0000"), endDate: f("2018-12-12 18:25:00 +0000"), value: 1.375, unit: .unitsPerHour, isMutable: true, wasProgrammedByPumpUI: true), raw: Data(hexadecimalString: "3094c121601fa2")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 05 second: 0 isLeapMonth: false )", type: .tempBasal)
        ]

        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate = f("2018-12-12 18:05:00 +0000")
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:07:14 +0000")

        let addPumpEvents2 = expectation(description: "addPumpEvents2")
        addPumpEvents2.expectedFulfillmentCount = 2
        doseStore.addPumpEvents(pumpEvents2, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            doseStore.insulinDeliveryStore.getDoseEntries { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 1)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                    XCTAssertFalse(doseEntries[0].wasProgrammedByPumpUI)
                }
                addPumpEvents2.fulfill();
            }
            doseStore.insulinDeliveryStore.getDoseEntries(includeMutable: true) { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 2)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                    XCTAssertEqual(doseEntries[1].type, .tempBasal)
                    XCTAssertEqual(doseEntries[1].startDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[1].endDate, f("2018-12-12 18:25:00 +0000"))
                    XCTAssertEqual(doseEntries[1].value, 1.375)
                    XCTAssertNil(doseEntries[1].deliveredUnits)
                    XCTAssertEqual(doseEntries[1].syncIdentifier, "3094c121601fa2")
                    XCTAssertEqual(doseEntries[1].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertTrue(doseEntries[1].isMutable)
                    XCTAssertTrue(doseEntries[1].wasProgrammedByPumpUI)
                }
                addPumpEvents2.fulfill();
            }
        }

        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:00 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)

        // 4. Update the mutable temp basal that crossing scheduled basal boundary. It should persist in InsulinDeliveryStore.
        let pumpEvents3 = [
            NewPumpEvent(date: f("2018-12-12 18:05:00 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 18:05:00 +0000"), endDate: f("2018-12-12 18:35:00 +0000"), value: 0.875, unit: .unitsPerHour, isMutable: true), raw: Data(hexadecimalString: "3094c121601fa2")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 05 second: 0 isLeapMonth: false )", type: .tempBasal)
        ]

        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate = f("2018-12-12 18:05:00 +0000")
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:07:14 +0000")

        let addPumpEvents3 = expectation(description: "addPumpEvents3")
        addPumpEvents3.expectedFulfillmentCount = 2
        doseStore.addPumpEvents(pumpEvents3, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            doseStore.insulinDeliveryStore.getDoseEntries { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 1)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                }
                addPumpEvents3.fulfill();
            }
            doseStore.insulinDeliveryStore.getDoseEntries(includeMutable: true) { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 3)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                    XCTAssertEqual(doseEntries[1].type, .tempBasal)
                    XCTAssertEqual(doseEntries[1].startDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[1].endDate, f("2018-12-12 18:30:00 +0000"))
                    XCTAssertEqual(doseEntries[1].value, 0.875)
                    XCTAssertNil(doseEntries[1].deliveredUnits)
                    XCTAssertEqual(doseEntries[1].syncIdentifier, "3094c121601fa2 1/2")
                    XCTAssertEqual(doseEntries[1].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertTrue(doseEntries[1].isMutable)
                    XCTAssertEqual(doseEntries[2].type, .tempBasal)
                    XCTAssertEqual(doseEntries[2].startDate, f("2018-12-12 18:30:00 +0000"))
                    XCTAssertEqual(doseEntries[2].endDate, f("2018-12-12 18:35:00 +0000"))
                    XCTAssertEqual(doseEntries[2].value, 0.875)
                    XCTAssertNil(doseEntries[2].deliveredUnits)
                    XCTAssertEqual(doseEntries[2].syncIdentifier, "3094c121601fa2 2/2")
                    XCTAssertEqual(doseEntries[2].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.0))
                    XCTAssertTrue(doseEntries[2].isMutable)
                }
                addPumpEvents3.fulfill();
            }
        }

        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:00 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)

        // 5. Add a different mutable temp basal that crossing scheduled basal boundary. It should persist in InsulinDeliveryStore. A scheduled basal should be added.
        let pumpEvents4 = [
            NewPumpEvent(date: f("2018-12-12 18:15:00 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 18:15:00 +0000"), endDate: f("2018-12-12 18:45:00 +0000"), value: 0.5, unit: .unitsPerHour, isMutable: true), raw: Data(hexadecimalString: "121601f3094ca2")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 15 second: 0 isLeapMonth: false )", type: .tempBasal)
        ]

        var basalDoseEntry: DoseEntry? = nil

        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate = f("2018-12-12 18:05:00 +0000")
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:17:14 +0000")

        let addPumpEvents4 = expectation(description: "addPumpEvents4")
        addPumpEvents4.expectedFulfillmentCount = 2
        doseStore.addPumpEvents(pumpEvents4, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            doseStore.insulinDeliveryStore.getDoseEntries { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 2)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                    XCTAssertEqual(doseEntries[1].type, .basal)
                    XCTAssertEqual(doseEntries[1].startDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[1].endDate, f("2018-12-12 18:15:00 +0000"))
                    XCTAssertEqual(doseEntries[1].value, 0.15)
                    XCTAssertNil(doseEntries[1].deliveredUnits)
                    XCTAssertEqual(doseEntries[1].syncIdentifier, "BasalRateSchedule 2018-12-12T18:05:00Z 2018-12-12T18:15:00Z")
                    XCTAssertEqual(doseEntries[1].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[1].isMutable)

                    basalDoseEntry = doseEntries[1]
                }
                addPumpEvents4.fulfill();
            }
            doseStore.insulinDeliveryStore.getDoseEntries(includeMutable: true) { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 4)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                    XCTAssertEqual(doseEntries[1].type, .basal)
                    XCTAssertEqual(doseEntries[1].startDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[1].endDate, f("2018-12-12 18:15:00 +0000"))
                    XCTAssertEqual(doseEntries[1].value, 0.15)
                    XCTAssertNil(doseEntries[1].deliveredUnits)
                    XCTAssertEqual(doseEntries[1].syncIdentifier, "BasalRateSchedule 2018-12-12T18:05:00Z 2018-12-12T18:15:00Z")
                    XCTAssertEqual(doseEntries[1].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[1].isMutable)
                    XCTAssertEqual(doseEntries[2].type, .tempBasal)
                    XCTAssertEqual(doseEntries[2].startDate, f("2018-12-12 18:15:00 +0000"))
                    XCTAssertEqual(doseEntries[2].endDate, f("2018-12-12 18:30:00 +0000"))
                    XCTAssertEqual(doseEntries[2].value, 0.5)
                    XCTAssertNil(doseEntries[2].deliveredUnits)
                    XCTAssertEqual(doseEntries[2].syncIdentifier, "121601f3094ca2 1/2")
                    XCTAssertEqual(doseEntries[2].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertTrue(doseEntries[2].isMutable)
                    XCTAssertEqual(doseEntries[3].type, .tempBasal)
                    XCTAssertEqual(doseEntries[3].startDate, f("2018-12-12 18:30:00 +0000"))
                    XCTAssertEqual(doseEntries[3].endDate, f("2018-12-12 18:45:00 +0000"))
                    XCTAssertEqual(doseEntries[3].value, 0.5)
                    XCTAssertNil(doseEntries[3].deliveredUnits)
                    XCTAssertEqual(doseEntries[3].syncIdentifier, "121601f3094ca2 2/2")
                    XCTAssertEqual(doseEntries[3].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.0))
                    XCTAssertTrue(doseEntries[3].isMutable)
                }
                addPumpEvents4.fulfill();
            }
        }

        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:15:00 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)

        // 6. Deleted scheduled basal dose entry. Tombstones entry so should not be returned again.
        let addPumpEvents5 = expectation(description: "addPumpEvents5")
        doseStore.deleteDose(basalDoseEntry!) { result in
            XCTAssertNil(result)
            addPumpEvents5.fulfill();
        }

        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:05:00 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)

        // 7. Add an immutable temp basal that crossing scheduled basal boundary. It should persist in InsulinDeliveryStore.
        let pumpEvents6 = [
            NewPumpEvent(date: f("2018-12-12 18:25:00 +0000"), dose: DoseEntry(type: .tempBasal, startDate: f("2018-12-12 18:25:00 +0000"), endDate: f("2018-12-12 18:40:00 +0000"), value: 0.75, unit: .unitsPerHour), raw: Data(hexadecimalString: "1201f3094c16a2")!, title: "TempBasalDurationPumpEvent(length: 7, rawData: 7 bytes, duration: 30, timestamp: calendar: gregorian (fixed) year: 2018 month: 12 day: 12 hour: 10 minute: 25 second: 0 isLeapMonth: false )", type: .tempBasal)
        ]

        doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate = f("2018-12-12 18:05:00 +0000")
        doseStore.insulinDeliveryStore.test_currentDate = f("2018-12-12 18:41:14 +0000")

        let addPumpEvents6 = expectation(description: "addPumpEvents6")
        addPumpEvents6.expectedFulfillmentCount = 2
        doseStore.addPumpEvents(pumpEvents6, lastReconciliation: Date()) { (error) in
            XCTAssertNil(error)
            doseStore.insulinDeliveryStore.getDoseEntries { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 4)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                    XCTAssertEqual(doseEntries[1].type, .basal)
                    XCTAssertEqual(doseEntries[1].startDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[1].endDate, f("2018-12-12 18:25:00 +0000"))
                    XCTAssertEqual(doseEntries[1].value, 0.3)
                    XCTAssertNil(doseEntries[1].deliveredUnits)
                    XCTAssertEqual(doseEntries[1].syncIdentifier, "BasalRateSchedule 2018-12-12T18:05:00Z 2018-12-12T18:25:00Z")
                    XCTAssertEqual(doseEntries[1].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[1].isMutable)
                    XCTAssertEqual(doseEntries[2].type, .tempBasal)
                    XCTAssertEqual(doseEntries[2].startDate, f("2018-12-12 18:25:00 +0000"))
                    XCTAssertEqual(doseEntries[2].endDate, f("2018-12-12 18:30:00 +0000"))
                    XCTAssertEqual(doseEntries[2].value, 0.75)
                    XCTAssertEqual(doseEntries[2].deliveredUnits, 0.06666666666666667)
                    XCTAssertEqual(doseEntries[2].syncIdentifier, "1201f3094c16a2 1/2")
                    XCTAssertEqual(doseEntries[2].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[2].isMutable)
                    XCTAssertEqual(doseEntries[3].type, .tempBasal)
                    XCTAssertEqual(doseEntries[3].startDate, f("2018-12-12 18:30:00 +0000"))
                    XCTAssertEqual(doseEntries[3].endDate, f("2018-12-12 18:40:00 +0000"))
                    XCTAssertEqual(doseEntries[3].value, 0.75)
                    XCTAssertEqual(doseEntries[3].deliveredUnits, 0.13333333333333333)
                    XCTAssertEqual(doseEntries[3].syncIdentifier, "1201f3094c16a2 2/2")
                    XCTAssertEqual(doseEntries[3].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.0))
                    XCTAssertFalse(doseEntries[3].isMutable)
                }
                addPumpEvents6.fulfill();
            }
            doseStore.insulinDeliveryStore.getDoseEntries(includeMutable: true) { result in
                switch result {
                case .failure:
                    XCTFail()
                case .success(let doseEntries):
                    XCTAssertEqual(doseEntries.count, 4)
                    XCTAssertEqual(doseEntries[0].type, .tempBasal)
                    XCTAssertEqual(doseEntries[0].startDate, f("2018-12-12 17:35:00 +0000"))
                    XCTAssertEqual(doseEntries[0].endDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[0].value, 2.125)
                    XCTAssertEqual(doseEntries[0].deliveredUnits, 1.05)
                    XCTAssertEqual(doseEntries[0].syncIdentifier, "1601fa23094c12")
                    XCTAssertEqual(doseEntries[0].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[0].isMutable)
                    XCTAssertEqual(doseEntries[1].type, .basal)
                    XCTAssertEqual(doseEntries[1].startDate, f("2018-12-12 18:05:00 +0000"))
                    XCTAssertEqual(doseEntries[1].endDate, f("2018-12-12 18:25:00 +0000"))
                    XCTAssertEqual(doseEntries[1].value, 0.3)
                    XCTAssertNil(doseEntries[1].deliveredUnits)
                    XCTAssertEqual(doseEntries[1].syncIdentifier, "BasalRateSchedule 2018-12-12T18:05:00Z 2018-12-12T18:25:00Z")
                    XCTAssertEqual(doseEntries[1].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[1].isMutable)
                    XCTAssertEqual(doseEntries[2].type, .tempBasal)
                    XCTAssertEqual(doseEntries[2].startDate, f("2018-12-12 18:25:00 +0000"))
                    XCTAssertEqual(doseEntries[2].endDate, f("2018-12-12 18:30:00 +0000"))
                    XCTAssertEqual(doseEntries[2].value, 0.75)
                    XCTAssertEqual(doseEntries[2].deliveredUnits, 0.06666666666666667)
                    XCTAssertEqual(doseEntries[2].syncIdentifier, "1201f3094c16a2 1/2")
                    XCTAssertEqual(doseEntries[2].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 0.85))
                    XCTAssertFalse(doseEntries[2].isMutable)
                    XCTAssertEqual(doseEntries[3].type, .tempBasal)
                    XCTAssertEqual(doseEntries[3].startDate, f("2018-12-12 18:30:00 +0000"))
                    XCTAssertEqual(doseEntries[3].endDate, f("2018-12-12 18:40:00 +0000"))
                    XCTAssertEqual(doseEntries[3].value, 0.75)
                    XCTAssertEqual(doseEntries[3].deliveredUnits, 0.13333333333333333)
                    XCTAssertEqual(doseEntries[3].syncIdentifier, "1201f3094c16a2 2/2")
                    XCTAssertEqual(doseEntries[3].scheduledBasalRate, HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.0))
                    XCTAssertFalse(doseEntries[3].isMutable)
                }
                addPumpEvents6.fulfill();
            }
        }

        waitForExpectations(timeout: 3)

        XCTAssertEqual(f("2018-12-12 18:40:00 +0000"), doseStore.insulinDeliveryStore.test_lastImmutableBasalEndDate)
    }
}

class DoseStoreQueryAnchorTests: XCTestCase {
    
    var rawValue: DoseStore.QueryAnchor.RawValue = [
        "modificationCounter": Int64(123)
    ]
    
    func testInitializerDefault() {
        let queryAnchor = DoseStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.modificationCounter, 0)
    }
    
    func testInitializerRawValue() {
        let queryAnchor = DoseStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.modificationCounter, 123)
    }
    
    func testInitializerRawValueMissingModificationCounter() {
        rawValue["modificationCounter"] = nil
        XCTAssertNil(DoseStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testInitializerRawValueInvalidModificationCounter() {
        rawValue["modificationCounter"] = "123"
        XCTAssertNil(DoseStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testRawValueWithDefault() {
        let rawValue = DoseStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(0))
    }
    
    func testRawValueWithNonDefault() {
        var queryAnchor = DoseStore.QueryAnchor()
        queryAnchor.modificationCounter = 123
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(123))
    }
    
}

class DoseStoreQueryTests: PersistenceControllerTestCase {
    
    let insulinModel = WalshInsulinModel(actionDuration: .hours(4))
    let basalProfile = BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]])
    let insulinSensitivitySchedule = InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]])
    
    var doseStore: DoseStore!
    var completion: XCTestExpectation!
    var queryAnchor: DoseStore.QueryAnchor!
    var limit: Int!
    
    override func setUp() {
        super.setUp()
        
        doseStore = DoseStore(healthStore: HKHealthStoreMock(),
                              cacheStore: cacheStore,
                              observationEnabled: false,
                              insulinModelProvider: StaticInsulinModelProvider(insulinModel),
                              longestEffectDuration: insulinModel.effectDuration,
                              basalProfile: basalProfile,
                              insulinSensitivitySchedule: insulinSensitivitySchedule,
                              provenanceIdentifier: Bundle.main.bundleIdentifier!)

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            semaphore.signal()
        }
        semaphore.wait()

        completion = expectation(description: "Completion")
        queryAnchor = DoseStore.QueryAnchor()
        limit = Int.max
    }
    
    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        doseStore = nil
        
        super.tearDown()
    }

    func testPumpEventEmptyWithDefaultQueryAnchor() {
        doseStore.executePumpEventQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpEventEmptyWithMissingQueryAnchor() {
        queryAnchor = nil
        
        doseStore.executePumpEventQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpEventEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.modificationCounter = 1
        
        doseStore.executePumpEventQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 1)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpEventDataWithUnusedQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addPumpEventData(withSyncIdentifiers: syncIdentifiers)

        doseStore.executePumpEventQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 3)
                for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                    XCTAssertEqual(data[index].raw?.hexadecimalString, syncIdentifier)
                }
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpEventDataWithStaleQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addPumpEventData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.modificationCounter = 2
        
        doseStore.executePumpEventQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 1)
                XCTAssertEqual(data[0].raw?.hexadecimalString, syncIdentifiers[2])
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpEventDataWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addPumpEventData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.modificationCounter = 3
        
        doseStore.executePumpEventQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testPumpEventDataWithLimitCoveredByData() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addPumpEventData(withSyncIdentifiers: syncIdentifiers)

        limit = 2
        
        doseStore.executePumpEventQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 2)
                XCTAssertEqual(data.count, 2)
                XCTAssertEqual(data[0].raw?.hexadecimalString, syncIdentifiers[0])
                XCTAssertEqual(data[1].raw?.hexadecimalString, syncIdentifiers[1])
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    private func addPumpEventData(withSyncIdentifiers syncIdentifiers: [String]) {
        cacheStore.managedObjectContext.performAndWait {
            for syncIdentifier in syncIdentifiers {
                let pumpEvent = PumpEvent(context: self.cacheStore.managedObjectContext)
                pumpEvent.date = Date()
                pumpEvent.type = PumpEventType.allCases.randomElement()!
                pumpEvent.raw = Data(hexadecimalString: syncIdentifier)
                
                self.cacheStore.save()
            }
        }
    }
    
    private func generateSyncIdentifier() -> String {
        return UUID().data.hexadecimalString
    }
    
}

class DoseStoreCriticalEventLogTests: PersistenceControllerTestCase {
    let insulinModel = WalshInsulinModel(actionDuration: .hours(4))
    let basalProfile = BasalRateSchedule(rawValue: ["timeZone": -28800, "items": [["value": 0.75, "startTime": 0.0], ["value": 0.8, "startTime": 10800.0], ["value": 0.85, "startTime": 32400.0], ["value": 1.0, "startTime": 68400.0]]])
    let insulinSensitivitySchedule = InsulinSensitivitySchedule(rawValue: ["unit": "mg/dL", "timeZone": -28800, "items": [["value": 40.0, "startTime": 0.0], ["value": 35.0, "startTime": 21600.0], ["value": 40.0, "startTime": 57600.0]]])

    var doseStore: DoseStore!
    var outputStream: MockOutputStream!
    var progress: Progress!
    
    override func setUp() {
        super.setUp()

        let persistedDate = dateFormatter.date(from: "2100-01-02T03:00:00Z")!
        let url = URL(string: "http://a.b.com")!
        let events = [PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:08:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil),
                      PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:10:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil),
                      PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:04:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil),
                      PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:06:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil),
                      PersistedPumpEvent(date: dateFormatter.date(from: "2100-01-02T03:02:00Z")!, persistedDate: persistedDate, dose: nil, isUploaded: false, objectIDURL: url, raw: nil, title: nil, type: nil)]

        doseStore = DoseStore(healthStore: HKHealthStoreMock(),
                              cacheStore: cacheStore,
                              observationEnabled: false,
                              insulinModelProvider: StaticInsulinModelProvider(insulinModel),
                              longestEffectDuration: insulinModel.effectDuration,
                              basalProfile: basalProfile,
                              insulinSensitivitySchedule: insulinSensitivitySchedule,
                              provenanceIdentifier: Bundle.main.bundleIdentifier!)
        XCTAssertNil(doseStore.addPumpEvents(events: events))

        outputStream = MockOutputStream()
        progress = Progress()
    }

    override func tearDown() {
        doseStore = nil

        super.tearDown()
    }
    
    func testExportProgressTotalUnitCount() {
        switch doseStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                      endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 3 * 1)
        }
    }
    
    func testExportProgressTotalUnitCountEmpty() {
        switch doseStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                                      endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 0)
        }
    }

    func testExport() {
        XCTAssertNil(doseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                      endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                      to: outputStream,
                                      progress: progress))
        XCTAssertEqual(outputStream.string, """
[
{"createdAt":"2100-01-02T03:00:00.000Z","date":"2100-01-02T03:08:00.000Z","duration":0,"insulinType":0,"modificationCounter":1,"mutable":false,"uploaded":false,"wasProgrammedByPumpUI":false},
{"createdAt":"2100-01-02T03:00:00.000Z","date":"2100-01-02T03:04:00.000Z","duration":0,"insulinType":0,"modificationCounter":3,"mutable":false,"uploaded":false,"wasProgrammedByPumpUI":false},
{"createdAt":"2100-01-02T03:00:00.000Z","date":"2100-01-02T03:06:00.000Z","duration":0,"insulinType":0,"modificationCounter":4,"mutable":false,"uploaded":false,"wasProgrammedByPumpUI":false}
]
"""
        )
        XCTAssertEqual(progress.completedUnitCount, 3 * 1)
    }
    
    func testExportEmpty() {
        XCTAssertNil(doseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                      endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!,
                                      to: outputStream,
                                      progress: progress))
        XCTAssertEqual(outputStream.string, "[]")
        XCTAssertEqual(progress.completedUnitCount, 0)
    }

    func testExportCancelled() {
        progress.cancel()
        XCTAssertEqual(doseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                        endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                        to: outputStream,
                                        progress: progress) as? CriticalEventLogError, CriticalEventLogError.cancelled)
    }

    private let dateFormatter = ISO8601DateFormatter()
}

class DoseStoreEffectTests: PersistenceControllerTestCase {
    var doseStore: DoseStore!

    var insulinSensitivitySchedule: InsulinSensitivitySchedule {
        return InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0.0, value: 40.0)], timeZone: .currentFixed)!
    }

    let dateFormatter = ISO8601DateFormatter.localTimeDate()

    override func setUp() {
        super.setUp()
        let healthStore = HKHealthStoreMock()
        let exponentialInsulinModel: InsulinModel = ExponentialInsulinModelPreset.rapidActingAdult
        let startDate = dateFormatter.date(from: "2015-07-13T12:00:00")!

        doseStore = DoseStore(
            healthStore: healthStore,
            observeHealthKitSamplesFromOtherApps: false,
            cacheStore: cacheStore,
            observationEnabled: false,
            insulinModelProvider: StaticInsulinModelProvider(exponentialInsulinModel),
            longestEffectDuration: exponentialInsulinModel.effectDuration,
            basalProfile: BasalRateSchedule(dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 1.0)]),
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            overrideHistory: TemporaryScheduleOverrideHistory(),
            provenanceIdentifier: Bundle.main.bundleIdentifier!,
            test_currentDate: startDate
        )
    }
    
    override func tearDown() {
        doseStore = nil
        
        super.tearDown()
    }

    func loadGlucoseEffectFixture(_ resourceName: String) -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture(resourceName)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
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

            var scheduledBasalRate: HKQuantity? = nil
            if let scheduled = $0["scheduled"] as? Double {
                scheduledBasalRate = HKQuantity(unit: unit.unit, doubleValue: scheduled)
            }

            return DoseEntry(
                type: type,
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                endDate: dateFormatter.date(from: $0["end_at"] as! String)!,
                value: $0["amount"] as! Double,
                unit: unit,
                description: $0["description"] as? String,
                syncIdentifier: $0["raw"] as? String,
                scheduledBasalRate: scheduledBasalRate
            )
        }
    }

    func injectDoseEvents(from fixture: String) {
        let events = loadDoseFixture(fixture).map {
            NewPumpEvent(
                date: $0.startDate,
                dose: $0,
                raw: Data(UUID().uuidString.utf8),
                title: "",
                type: $0.type.pumpEventType
            )
        }

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        doseStore.addPumpEvents(events, lastReconciliation: nil) { error in
            if error != nil {
                XCTFail("Doses should be added successfully to dose store")
            }
            updateGroup.leave()
        }
        updateGroup.wait()
    }

    func testGlucoseEffectFromTempBasal() {
        injectDoseEvents(from: "basal_dose")
        let output = loadGlucoseEffectFixture("effect_from_basal_output_exponential")

        var insulinEffects: [GlucoseEffect]!
        let startDate = dateFormatter.date(from: "2015-07-13T12:00:00")!
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        doseStore.getGlucoseEffects(start: startDate) { (result) -> Void in
            switch result {
            case .failure(let error):
                print(error)
                XCTFail("Mock should always return success")
            case .success(let effects):
                insulinEffects = effects
            }
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(output.count, insulinEffects.count)

        for (expected, calculated) in zip(output, insulinEffects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 1.0, String(describing: expected.startDate))
        }
    }

    func testGlucoseEffectFromTempBasalWithOldDoses() {
        injectDoseEvents(from: "basal_dose_with_expired")
        let output = loadGlucoseEffectFixture("effect_from_basal_output_exponential")

        var insulinEffects: [GlucoseEffect]!
        let startDate = dateFormatter.date(from: "2015-07-13T12:00:00")!
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        doseStore.getGlucoseEffects(start: startDate) { (result) -> Void in
            switch result {
            case .failure(let error):
                print(error)
                XCTFail("Mock should always return success")
            case .success(let effects):
                insulinEffects = effects
            }
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(output.count, insulinEffects.count)

        for (expected, calculated) in zip(output, insulinEffects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 1.0, String(describing: expected.startDate))
        }
    }

    func testGlucoseEffectFromHistory() {
        injectDoseEvents(from: "dose_history_with_delivered_units")
        let output = loadGlucoseEffectFixture("effect_from_history_exponential_delivered_units_output")

        var insulinEffects: [GlucoseEffect]!
        let startDate = dateFormatter.date(from: "2016-01-30T15:40:49")!
        let updateGroup = DispatchGroup()
        updateGroup.enter()
        doseStore.getGlucoseEffects(start: startDate) { (result) -> Void in
            switch result {
            case .failure(let error):
                print(error)
                XCTFail("Mock should always return success")
            case .success(let effects):
                insulinEffects = effects
            }
            updateGroup.leave()
        }
        updateGroup.wait()

        XCTAssertEqual(output.count, insulinEffects.count)

        for (expected, calculated) in zip(output, insulinEffects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: 1.0, String(describing: expected.startDate))
        }
    }
}
