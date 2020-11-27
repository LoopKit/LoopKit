//
//  InsulinDeliveryStoreTests.swift
//  LoopKitHostedTests
//
//  Created by Darin Krauss on 10/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class InsulinDeliveryStoreTests: PersistenceControllerTestCase {
    private let entry1 = DoseEntry(type: .basal,
                                   startDate: Date(timeIntervalSinceNow: -.minutes(6)),
                                   endDate: Date(timeIntervalSinceNow: -.minutes(5.5)),
                                   value: 1.8,
                                   unit: .unitsPerHour,
                                   deliveredUnits: 0.015,
                                   syncIdentifier: "4B14522E-A7B5-4E73-B76B-5043CD7176B0",
                                   scheduledBasalRate: nil)
    private let entry2 = DoseEntry(type: .tempBasal,
                                   startDate: Date(timeIntervalSinceNow: -.minutes(2)),
                                   endDate: Date(timeIntervalSinceNow: -.minutes(1.5)),
                                   value: 2.4,
                                   unit: .unitsPerHour,
                                   deliveredUnits: 0.02,
                                   syncIdentifier: "A1F8E29B-33D6-4B38-B4CD-D84F14744871",
                                   scheduledBasalRate: HKQuantity(unit: .internationalUnitsPerHour, doubleValue: 1.8))
    private let entry3 = DoseEntry(type: .bolus,
                                   startDate: Date(timeIntervalSinceNow: -.minutes(4)),
                                   endDate: Date(timeIntervalSinceNow: -.minutes(3.5)),
                                   value: 1.0,
                                   unit: .units,
                                   deliveredUnits: nil,
                                   syncIdentifier: "1A1D6192-1521-4469-B962-1B82C4534BB1",
                                   scheduledBasalRate: nil)
    private let device = HKDevice(name: UUID().uuidString,
                                  manufacturer: UUID().uuidString,
                                  model: UUID().uuidString,
                                  hardwareVersion: UUID().uuidString,
                                  firmwareVersion: UUID().uuidString,
                                  softwareVersion: UUID().uuidString,
                                  localIdentifier: UUID().uuidString,
                                  udiDeviceIdentifier: UUID().uuidString)

    var healthStore: HKHealthStoreMock!
    var insulinDeliveryStore: InsulinDeliveryStore!

    override func setUp() {
        super.setUp()

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { error in
            XCTAssertNil(error)
            semaphore.signal()
        }
        semaphore.wait()

        healthStore = HKHealthStoreMock()
        insulinDeliveryStore = InsulinDeliveryStore(healthStore: healthStore,
                                                    cacheStore: cacheStore,
                                                    cacheLength: .hours(1),
                                                    provenanceIdentifier: HKSource.default().bundleIdentifier)
    }

    override func tearDown() {
        let semaphore = DispatchSemaphore(value: 0)
        insulinDeliveryStore.purgeAllDoseEntries(healthKitPredicate: HKQuery.predicateForObjects(from: HKSource.default())) { error in
            XCTAssertNil(error)
            semaphore.signal()
        }
        semaphore.wait()

        insulinDeliveryStore = nil
        healthStore = nil

        super.tearDown()
    }

    // MARK: - HealthKitSampleStore

    func testHealthKitQueryAnchorPersistence() {
        var observerQuery: HKObserverQueryMock? = nil
        var anchoredObjectQuery: HKAnchoredObjectQueryMock? = nil

        insulinDeliveryStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            return observerQuery!
        }

        let authorizationCompletion = expectation(description: "authorization completion")
        insulinDeliveryStore.authorize { (result) in
            authorizationCompletion.fulfill()
        }

        waitForExpectations(timeout: 10)

        XCTAssertNotNil(observerQuery)

        let anchoredObjectQueryCreationExpectation = expectation(description: "anchored object query creation")
        insulinDeliveryStore.createAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) -> HKAnchoredObjectQuery in
            anchoredObjectQuery = HKAnchoredObjectQueryMock(type: sampleType, predicate: predicate, anchor: anchor, limit: limit, resultsHandler: resultsHandler)
            anchoredObjectQueryCreationExpectation.fulfill()
            return anchoredObjectQuery!
        }

        let observerQueryCompletionExpectation = expectation(description: "observer query completion")

        let observerQueryCompletionHandler = {
            observerQueryCompletionExpectation.fulfill()
        }
        // This simulates a signal marking the arrival of new HK Data.
        observerQuery!.updateHandler(observerQuery!, observerQueryCompletionHandler, nil)

        wait(for: [anchoredObjectQueryCreationExpectation], timeout: 10)

        // Trigger results handler for anchored object query
        let returnedAnchor = HKQueryAnchor(fromValue: 5)
        anchoredObjectQuery!.resultsHandler(anchoredObjectQuery!, [], [], returnedAnchor, nil)

        // Wait for observerQueryCompletionExpectation
        waitForExpectations(timeout: 10)

        XCTAssertNotNil(insulinDeliveryStore.queryAnchor)

        cacheStore.managedObjectContext.performAndWait {}

        // Create a new glucose store, and ensure it uses the last query anchor
        let newInsulinDeliveryStore = InsulinDeliveryStore(healthStore: healthStore,
                                                           cacheStore: cacheStore,
                                                           provenanceIdentifier: HKSource.default().bundleIdentifier)

        let newAuthorizationCompletion = expectation(description: "authorization completion")

        observerQuery = nil

        newInsulinDeliveryStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            return observerQuery!
        }

        newInsulinDeliveryStore.authorize { (result) in
            newAuthorizationCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        anchoredObjectQuery = nil

        let newAnchoredObjectQueryCreationExpectation = expectation(description: "new anchored object query creation")
        newInsulinDeliveryStore.createAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) -> HKAnchoredObjectQuery in
            anchoredObjectQuery = HKAnchoredObjectQueryMock(type: sampleType, predicate: predicate, anchor: anchor, limit: limit, resultsHandler: resultsHandler)
            newAnchoredObjectQueryCreationExpectation.fulfill()
            return anchoredObjectQuery!
        }

        // This simulates a signal marking the arrival of new HK Data.
        observerQuery!.updateHandler(observerQuery!, {}, nil)

        waitForExpectations(timeout: 10)

        // Assert new glucose store is querying with the last anchor that our HealthKit mock returned
        XCTAssertEqual(returnedAnchor, anchoredObjectQuery?.anchor)

        anchoredObjectQuery!.resultsHandler(anchoredObjectQuery!, [], [], returnedAnchor, nil)
    }

    // MARK: - Fetching

    func testGetDoseEntries() {
        let addDoseEntriesCompletion = expectation(description: "addDoseEntries")
        insulinDeliveryStore.addDoseEntries([entry1, entry2, entry3], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntriesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getDoseEntries1Completion = expectation(description: "getDoseEntries1")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 3)
                XCTAssertEqual(entries[0].type, self.entry1.type)
                XCTAssertEqual(entries[0].startDate, self.entry1.startDate)
                XCTAssertEqual(entries[0].endDate, self.entry1.endDate)
                XCTAssertEqual(entries[0].value, 0.015)
                XCTAssertEqual(entries[0].unit, .units)
                XCTAssertNil(entries[0].deliveredUnits)
                XCTAssertEqual(entries[0].description, self.entry1.description)
                XCTAssertEqual(entries[0].syncIdentifier, self.entry1.syncIdentifier)
                XCTAssertEqual(entries[0].scheduledBasalRate, self.entry1.scheduledBasalRate)
                XCTAssertEqual(entries[1].type, self.entry3.type)
                XCTAssertEqual(entries[1].startDate, self.entry3.startDate)
                XCTAssertEqual(entries[1].endDate, self.entry3.endDate)
                XCTAssertEqual(entries[1].value, self.entry3.value)
                XCTAssertEqual(entries[1].unit, self.entry3.unit)
                XCTAssertEqual(entries[1].deliveredUnits, self.entry3.deliveredUnits)
                XCTAssertEqual(entries[1].description, self.entry3.description)
                XCTAssertEqual(entries[1].syncIdentifier, self.entry3.syncIdentifier)
                XCTAssertEqual(entries[1].scheduledBasalRate, self.entry3.scheduledBasalRate)
                XCTAssertEqual(entries[2].type, self.entry2.type)
                XCTAssertEqual(entries[2].startDate, self.entry2.startDate)
                XCTAssertEqual(entries[2].endDate, self.entry2.endDate)
                XCTAssertEqual(entries[2].value, self.entry2.value)
                XCTAssertEqual(entries[2].unit, self.entry2.unit)
                XCTAssertEqual(entries[2].deliveredUnits, self.entry2.deliveredUnits)
                XCTAssertEqual(entries[2].description, self.entry2.description)
                XCTAssertEqual(entries[2].syncIdentifier, self.entry2.syncIdentifier)
                XCTAssertEqual(entries[2].scheduledBasalRate, self.entry2.scheduledBasalRate)
            }
            getDoseEntries1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getDoseEntries2Completion = expectation(description: "getDoseEntries2")
        insulinDeliveryStore.getDoseEntries(start: Date(timeIntervalSinceNow: -.minutes(5)), end: Date(timeIntervalSinceNow: -.minutes(3))) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 1)
                XCTAssertEqual(entries[0].type, self.entry3.type)
                XCTAssertEqual(entries[0].startDate, self.entry3.startDate)
                XCTAssertEqual(entries[0].endDate, self.entry3.endDate)
                XCTAssertEqual(entries[0].value, self.entry3.value)
                XCTAssertEqual(entries[0].unit, self.entry3.unit)
                XCTAssertEqual(entries[0].deliveredUnits, self.entry3.deliveredUnits)
                XCTAssertEqual(entries[0].description, self.entry3.description)
                XCTAssertEqual(entries[0].syncIdentifier, self.entry3.syncIdentifier)
                XCTAssertEqual(entries[0].scheduledBasalRate, self.entry3.scheduledBasalRate)
            }
            getDoseEntries2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeCachedInsulinDeliveryObjectsCompletion = expectation(description: "purgeCachedInsulinDeliveryObjects")
        insulinDeliveryStore.purgeCachedInsulinDeliveryObjects() { error in
            XCTAssertNil(error)
            purgeCachedInsulinDeliveryObjectsCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getDoseEntries3Completion = expectation(description: "getDoseEntries3")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 0)
            }
            getDoseEntries3Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testLastBasalEndDate() {
        let getLastBasalEndDate1Completion = expectation(description: "getLastBasalEndDate1")
        insulinDeliveryStore.getLastBasalEndDate() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let lastBasalEndDate):
                XCTAssertEqual(lastBasalEndDate, .distantPast)
            }
            getLastBasalEndDate1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let addDoseEntriesCompletion = expectation(description: "addDoseEntries")
        insulinDeliveryStore.addDoseEntries([entry1, entry2, entry3], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntriesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getLastBasalEndDate2Completion = expectation(description: "getLastBasalEndDate2")
        insulinDeliveryStore.getLastBasalEndDate() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let lastBasalEndDate):
                XCTAssertEqual(lastBasalEndDate, self.entry2.endDate)
            }
            getLastBasalEndDate2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeCachedInsulinDeliveryObjectsCompletion = expectation(description: "purgeCachedInsulinDeliveryObjects")
        insulinDeliveryStore.purgeCachedInsulinDeliveryObjects() { error in
            XCTAssertNil(error)
            purgeCachedInsulinDeliveryObjectsCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getLastBasalEndDate3Completion = expectation(description: "getLastBasalEndDate3")
        insulinDeliveryStore.getLastBasalEndDate() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let lastBasalEndDate):
                XCTAssertEqual(lastBasalEndDate, .distantPast)
            }
            getLastBasalEndDate3Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    // MARK: - Modification

    func testAddDoseEntries() {
        let addDoseEntries1Completion = expectation(description: "addDoseEntries1")
        insulinDeliveryStore.addDoseEntries([entry1, entry2, entry3], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntries1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getDoseEntries1Completion = expectation(description: "getDoseEntries1")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 3)
                XCTAssertEqual(entries[0].type, self.entry1.type)
                XCTAssertEqual(entries[0].startDate, self.entry1.startDate)
                XCTAssertEqual(entries[0].endDate, self.entry1.endDate)
                XCTAssertEqual(entries[0].value, 0.015)
                XCTAssertEqual(entries[0].unit, .units)
                XCTAssertNil(entries[0].deliveredUnits)
                XCTAssertEqual(entries[0].description, self.entry1.description)
                XCTAssertEqual(entries[0].syncIdentifier, self.entry1.syncIdentifier)
                XCTAssertEqual(entries[0].scheduledBasalRate, self.entry1.scheduledBasalRate)
                XCTAssertEqual(entries[1].type, self.entry3.type)
                XCTAssertEqual(entries[1].startDate, self.entry3.startDate)
                XCTAssertEqual(entries[1].endDate, self.entry3.endDate)
                XCTAssertEqual(entries[1].value, self.entry3.value)
                XCTAssertEqual(entries[1].unit, self.entry3.unit)
                XCTAssertEqual(entries[1].deliveredUnits, self.entry3.deliveredUnits)
                XCTAssertEqual(entries[1].description, self.entry3.description)
                XCTAssertEqual(entries[1].syncIdentifier, self.entry3.syncIdentifier)
                XCTAssertEqual(entries[1].scheduledBasalRate, self.entry3.scheduledBasalRate)
                XCTAssertEqual(entries[2].type, self.entry2.type)
                XCTAssertEqual(entries[2].startDate, self.entry2.startDate)
                XCTAssertEqual(entries[2].endDate, self.entry2.endDate)
                XCTAssertEqual(entries[2].value, self.entry2.value)
                XCTAssertEqual(entries[2].unit, self.entry2.unit)
                XCTAssertEqual(entries[2].deliveredUnits, self.entry2.deliveredUnits)
                XCTAssertEqual(entries[2].description, self.entry2.description)
                XCTAssertEqual(entries[2].syncIdentifier, self.entry2.syncIdentifier)
                XCTAssertEqual(entries[2].scheduledBasalRate, self.entry2.scheduledBasalRate)
            }
            getDoseEntries1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let addDoseEntries2Completion = expectation(description: "addDoseEntries2")
        insulinDeliveryStore.addDoseEntries([entry3, entry1, entry2], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntries2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getDoseEntries2Completion = expectation(description: "getDoseEntries2Completion")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 3)
                XCTAssertEqual(entries[0].type, self.entry1.type)
                XCTAssertEqual(entries[0].startDate, self.entry1.startDate)
                XCTAssertEqual(entries[0].endDate, self.entry1.endDate)
                XCTAssertEqual(entries[0].value, 0.015)
                XCTAssertEqual(entries[0].unit, .units)
                XCTAssertNil(entries[0].deliveredUnits)
                XCTAssertEqual(entries[0].description, self.entry1.description)
                XCTAssertEqual(entries[0].syncIdentifier, self.entry1.syncIdentifier)
                XCTAssertEqual(entries[0].scheduledBasalRate, self.entry1.scheduledBasalRate)
                XCTAssertEqual(entries[1].type, self.entry3.type)
                XCTAssertEqual(entries[1].startDate, self.entry3.startDate)
                XCTAssertEqual(entries[1].endDate, self.entry3.endDate)
                XCTAssertEqual(entries[1].value, self.entry3.value)
                XCTAssertEqual(entries[1].unit, self.entry3.unit)
                XCTAssertEqual(entries[1].deliveredUnits, self.entry3.deliveredUnits)
                XCTAssertEqual(entries[1].description, self.entry3.description)
                XCTAssertEqual(entries[1].syncIdentifier, self.entry3.syncIdentifier)
                XCTAssertEqual(entries[1].scheduledBasalRate, self.entry3.scheduledBasalRate)
                XCTAssertEqual(entries[2].type, self.entry2.type)
                XCTAssertEqual(entries[2].startDate, self.entry2.startDate)
                XCTAssertEqual(entries[2].endDate, self.entry2.endDate)
                XCTAssertEqual(entries[2].value, self.entry2.value)
                XCTAssertEqual(entries[2].unit, self.entry2.unit)
                XCTAssertEqual(entries[2].deliveredUnits, self.entry2.deliveredUnits)
                XCTAssertEqual(entries[2].description, self.entry2.description)
                XCTAssertEqual(entries[2].syncIdentifier, self.entry2.syncIdentifier)
                XCTAssertEqual(entries[2].scheduledBasalRate, self.entry2.scheduledBasalRate)
            }
            getDoseEntries2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testAddDoseEntriesEmpty() {
        let addDoseEntriesCompletion = expectation(description: "addDoseEntries")
        insulinDeliveryStore.addDoseEntries([], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntriesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testAddDoseEntriesNotification() {
        let doseEntriesDidChangeCompletion = expectation(description: "doseEntriesDidChange")
        let observer = NotificationCenter.default.addObserver(forName: InsulinDeliveryStore.doseEntriesDidChange, object: insulinDeliveryStore, queue: nil) { notification in
            let updateSource = notification.userInfo?[HealthKitSampleStore.notificationUpdateSourceKey] as? Int
            XCTAssertEqual(updateSource, UpdateSource.changedInApp.rawValue)
            doseEntriesDidChangeCompletion.fulfill()
        }

        let addDoseEntriesCompletion = expectation(description: "addDoseEntries")
        insulinDeliveryStore.addDoseEntries([entry1, entry2, entry3], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntriesCompletion.fulfill()
        }
        wait(for: [doseEntriesDidChangeCompletion, addDoseEntriesCompletion], timeout: 10, enforceOrder: true)

        NotificationCenter.default.removeObserver(observer)
    }

    // MARK: - Cache Management

    func testEarliestCacheDate() {
        XCTAssertEqual(insulinDeliveryStore.earliestCacheDate.timeIntervalSinceNow, -.hours(1), accuracy: 1)
    }

    func testPurgeAllDoseEntries() {
        let addDoseEntriesCompletion = expectation(description: "addDoseEntries")
        insulinDeliveryStore.addDoseEntries([entry1, entry2, entry3], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntriesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getDoseEntries1Completion = expectation(description: "getDoseEntries1")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 3)
            }
            getDoseEntries1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeAllDoseEntriesCompletion = expectation(description: "purgeAllDoseEntries")
        insulinDeliveryStore.purgeAllDoseEntries(healthKitPredicate: HKQuery.predicateForObjects(from: HKSource.default())) { error in
            XCTAssertNil(error)
            purgeAllDoseEntriesCompletion.fulfill()

        }
        waitForExpectations(timeout: 10)

        let getDoseEntries2Completion = expectation(description: "getDoseEntries2")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 0)
            }
            getDoseEntries2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testPurgeExpiredGlucoseObjects() {
        let expiredEntry = DoseEntry(type: .bolus,
                                     startDate: Date(timeIntervalSinceNow: -.hours(3)),
                                     endDate: Date(timeIntervalSinceNow: -.hours(2)),
                                     value: 3.0,
                                     unit: .units,
                                     deliveredUnits: nil,
                                     syncIdentifier: "7530B8CA-827A-4DE8-ADE3-9E10FF80A4A9",
                                     scheduledBasalRate: nil)

        let addDoseEntriesCompletion = expectation(description: "addDoseEntries")
        insulinDeliveryStore.addDoseEntries([entry1, entry2, entry3, expiredEntry], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntriesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getDoseEntriesCompletion = expectation(description: "getDoseEntries")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 3)
            }
            getDoseEntriesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testPurgeCachedInsulinDeliveryObjects() {
        let addDoseEntriesCompletion = expectation(description: "addDoseEntries")
        insulinDeliveryStore.addDoseEntries([entry1, entry2, entry3], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntriesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getDoseEntries1Completion = expectation(description: "getDoseEntries1")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 3)
            }
            getDoseEntries1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeCachedInsulinDeliveryObjects1Completion = expectation(description: "purgeCachedInsulinDeliveryObjects1")
        insulinDeliveryStore.purgeCachedInsulinDeliveryObjects(before: Date(timeIntervalSinceNow: -.minutes(5))) { error in
            XCTAssertNil(error)
            purgeCachedInsulinDeliveryObjects1Completion.fulfill()

        }
        waitForExpectations(timeout: 10)

        let getDoseEntries2Completion = expectation(description: "getDoseEntries2")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 2)
            }
            getDoseEntries2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeCachedInsulinDeliveryObjects2Completion = expectation(description: "purgeCachedInsulinDeliveryObjects2")
        insulinDeliveryStore.purgeCachedInsulinDeliveryObjects() { error in
            XCTAssertNil(error)
            purgeCachedInsulinDeliveryObjects2Completion.fulfill()

        }
        waitForExpectations(timeout: 10)

        let getDoseEntries3Completion = expectation(description: "getDoseEntries3")
        insulinDeliveryStore.getDoseEntries() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let entries):
                XCTAssertEqual(entries.count, 0)
            }
            getDoseEntries3Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testPurgeCachedInsulinDeliveryObjectsNotification() {
        let addDoseEntriesCompletion = expectation(description: "addDoseEntries")
        insulinDeliveryStore.addDoseEntries([entry1, entry2, entry3], from: device, syncVersion: 2) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success:
                break
            }
            addDoseEntriesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let doseEntriesDidChangeCompletion = expectation(description: "doseEntriesDidChange")
        let observer = NotificationCenter.default.addObserver(forName: InsulinDeliveryStore.doseEntriesDidChange, object: insulinDeliveryStore, queue: nil) { notification in
            let updateSource = notification.userInfo?[HealthKitSampleStore.notificationUpdateSourceKey] as? Int
            XCTAssertEqual(updateSource, UpdateSource.changedInApp.rawValue)
            doseEntriesDidChangeCompletion.fulfill()
        }

        let purgeCachedInsulinDeliveryObjectsCompletion = expectation(description: "purgeCachedInsulinDeliveryObjects")
        insulinDeliveryStore.purgeCachedInsulinDeliveryObjects() { error in
            XCTAssertNil(error)
            purgeCachedInsulinDeliveryObjectsCompletion.fulfill()

        }
        wait(for: [doseEntriesDidChangeCompletion, purgeCachedInsulinDeliveryObjectsCompletion], timeout: 10, enforceOrder: true)

        NotificationCenter.default.removeObserver(observer)
    }
}
