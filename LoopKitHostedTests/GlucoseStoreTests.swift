//
//  GlucoseStoreTests.swift
//  LoopKitHostedTests
//
//  Created by Darin Krauss on 10/12/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class GlucoseStoreTestsBase: PersistenceControllerTestCase, GlucoseStoreDelegate {
    private static let device = HKDevice(name: "NAME", manufacturer: "MANUFACTURER", model: "MODEL", hardwareVersion: "HARDWAREVERSION", firmwareVersion: "FIRMWAREVERSION", softwareVersion: "SOFTWAREVERSION", localIdentifier: "LOCALIDENTIFIER", udiDeviceIdentifier: "UDIDEVICEIDENTIFIER")
    internal let sample1 = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.minutes(6)),
                                            quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.4),
                                            condition: nil,
                                            trend: nil,
                                            trendRate: nil,
                                            isDisplayOnly: true,
                                            wasUserEntered: false,
                                            syncIdentifier: "1925558F-E98F-442F-BBA6-F6F75FB4FD91",
                                            syncVersion: 2,
                                            device: device)
    internal let sample2 = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.minutes(2)),
                                            quantity: HKQuantity(unit: .millimolesPerLiter, doubleValue: 7.4),
                                            condition: nil,
                                            trend: .flat,
                                            trendRate: HKQuantity(unit: .millimolesPerLiterPerMinute, doubleValue: 0.0),
                                            isDisplayOnly: false,
                                            wasUserEntered: true,
                                            syncIdentifier: "535F103C-3DFE-48F2-B15A-47313191E7B7",
                                            syncVersion: 3,
                                            device: device)
    internal let sample3 = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.minutes(4)),
                                            quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 400.0),
                                            condition: .aboveRange,
                                            trend: .upUpUp,
                                            trendRate: HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 4.2),
                                            isDisplayOnly: false,
                                            wasUserEntered: false,
                                            syncIdentifier: "E1624D2B-A971-41B8-B8A0-3A8212AC3D71",
                                            syncVersion: 4,
                                            device: device)

    var healthStore: HKHealthStoreMock!
    var glucoseStore: GlucoseStore!
    var delegateCompletion: XCTestExpectation?
    var authorizationStatus: HKAuthorizationStatus = .notDetermined

    override func setUp() {
        super.setUp()

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { error in
            XCTAssertNil(error)
            semaphore.signal()
        }
        semaphore.wait()

        healthStore = HKHealthStoreMock()
        healthStore.authorizationStatus = authorizationStatus
        glucoseStore = GlucoseStore(healthStore: healthStore,
                                    cacheStore: cacheStore,
                                    cacheLength: .hours(1),
                                    observationInterval: .minutes(30),
                                    provenanceIdentifier: HKSource.default().bundleIdentifier)
        glucoseStore.delegate = self
    }

    override func tearDown() {
        let semaphore = DispatchSemaphore(value: 0)
        glucoseStore.purgeAllGlucoseSamples(healthKitPredicate: HKQuery.predicateForObjects(from: HKSource.default())) { error in
            XCTAssertNil(error)
            semaphore.signal()
        }
        semaphore.wait()

        delegateCompletion = nil
        glucoseStore = nil
        healthStore = nil

        super.tearDown()
    }

    // MARK: - GlucoseStoreDelegate

    func glucoseStoreHasUpdatedGlucoseData(_ glucoseStore: GlucoseStore) {
        delegateCompletion?.fulfill()
    }
}

class GlucoseStoreTestsAuthorizationRequired: GlucoseStoreTestsBase {
    func testObserverQueryStartup() {
        XCTAssert(glucoseStore.authorizationRequired);
        XCTAssertNil(glucoseStore.observerQuery);

        let authorizationCompletion = expectation(description: "authorization completion")
        glucoseStore.authorize { (result) in
            authorizationCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)
        XCTAssertNotNil(glucoseStore.observerQuery);
    }
}

class GlucoseStoreTests: GlucoseStoreTestsBase {
    override func setUp() {
        authorizationStatus = .sharingAuthorized
        super.setUp()
    }
    
    // MARK: - HealthKitSampleStore

    func testHealthKitQueryAnchorPersistence() {
        var observerQuery: HKObserverQueryMock? = nil
        var anchoredObjectQuery: HKAnchoredObjectQueryMock? = nil

        // Check that an observer query was registered even without authorize() being called.
        XCTAssertFalse(glucoseStore.authorizationRequired);
        XCTAssertNotNil(glucoseStore.observerQuery);

        glucoseStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            return observerQuery!
        }

        let authorizationCompletion = expectation(description: "authorization completion")
        glucoseStore.authorize { (result) in
            authorizationCompletion.fulfill()
        }

        waitForExpectations(timeout: 10)

        XCTAssertNotNil(observerQuery)

        let anchoredObjectQueryCreationExpectation = expectation(description: "anchored object query creation")
        glucoseStore.createAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) -> HKAnchoredObjectQuery in
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

        XCTAssertNotNil(glucoseStore.queryAnchor)

        cacheStore.managedObjectContext.performAndWait {}

        // Create a new glucose store, and ensure it uses the last query anchor
        let newGlucoseStore = GlucoseStore(healthStore: healthStore,
                                           cacheStore: cacheStore,
                                           provenanceIdentifier: HKSource.default().bundleIdentifier)

        let newAuthorizationCompletion = expectation(description: "authorization completion")

        observerQuery = nil

        newGlucoseStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            return observerQuery!
        }

        newGlucoseStore.authorize { (result) in
            newAuthorizationCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        anchoredObjectQuery = nil

        let newAnchoredObjectQueryCreationExpectation = expectation(description: "new anchored object query creation")
        newGlucoseStore.createAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) -> HKAnchoredObjectQuery in
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

    func testGetGlucoseSamples() {
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample1)
                XCTAssertNotNil(samples[1].uuid)
                XCTAssertNil(samples[1].healthKitEligibleDate)
                assertEqualSamples(samples[1], self.sample3)
                XCTAssertNotNil(samples[2].uuid)
                XCTAssertNil(samples[2].healthKitEligibleDate)
                assertEqualSamples(samples[2], self.sample2)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples2Completion = expectation(description: "getGlucoseSamples2")
        glucoseStore.getGlucoseSamples(start: Date(timeIntervalSinceNow: -.minutes(5)), end: Date(timeIntervalSinceNow: -.minutes(3))) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 1)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample3)
            }
            getGlucoseSamples2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeCachedGlucoseObjectsCompletion = expectation(description: "purgeCachedGlucoseObjects")
        glucoseStore.purgeCachedGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeCachedGlucoseObjectsCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples3Completion = expectation(description: "getGlucoseSamples3")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            getGlucoseSamples3Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }
    
    enum Error: Swift.Error { case arbitrary }

    func testGetGlucoseSamplesDelayedHealthKitStorage() {
        glucoseStore.healthKitStorageDelay = .minutes(5)
        var hkobjects = [HKObject]()
        healthStore.setSaveHandler { o, _, _ in hkobjects = o }
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                // HealthKit storage is deferred, so the second 2 UUIDs are nil
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample1)
                XCTAssertNil(samples[1].uuid)
                XCTAssertNotNil(samples[1].healthKitEligibleDate)
                assertEqualSamples(samples[1], self.sample3)
                XCTAssertNil(samples[2].uuid)
                XCTAssertNotNil(samples[2].healthKitEligibleDate)
                assertEqualSamples(samples[2], self.sample2)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let stored = hkobjects[0] as! HKQuantitySample
        XCTAssertEqual(sample1.quantitySample.quantity, stored.quantity)
    }
    
    func testGetGlucoseSamplesErrorHealthKitStorage() {
        healthStore.saveError = Error.arbitrary
        var hkobjects = [HKObject]()
        healthStore.setSaveHandler { o, _, _ in hkobjects = o }
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                // HealthKit storage is deferred, so the second 2 UUIDs are nil
                XCTAssertNil(samples[0].uuid)
                XCTAssertNotNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample1)
                XCTAssertNil(samples[1].uuid)
                XCTAssertNotNil(samples[1].healthKitEligibleDate)
                assertEqualSamples(samples[1], self.sample3)
                XCTAssertNil(samples[2].uuid)
                XCTAssertNotNil(samples[2].healthKitEligibleDate)
                assertEqualSamples(samples[2], self.sample2)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        XCTAssertEqual(3, hkobjects.count)
    }

    func testGetGlucoseSamplesDeniedHealthKitStorage() {
        healthStore.authorizationStatus = .sharingDenied
        var hkobjects = [HKObject]()
        healthStore.setSaveHandler { o, _, _ in hkobjects = o }
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                // HealthKit storage is denied, so all UUIDs are nil
                XCTAssertNil(samples[0].uuid)
                XCTAssertNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample1)
                XCTAssertNil(samples[1].uuid)
                XCTAssertNil(samples[1].healthKitEligibleDate)
                assertEqualSamples(samples[1], self.sample3)
                XCTAssertNil(samples[2].uuid)
                XCTAssertNil(samples[2].healthKitEligibleDate)
                assertEqualSamples(samples[2], self.sample2)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        XCTAssertTrue(hkobjects.isEmpty)
    }
    
    func testGetGlucoseSamplesSomeDeniedHealthKitStorage() {
        glucoseStore.healthKitStorageDelay = 0
        var hkobjects = [HKObject]()
        healthStore.setSaveHandler { o, _, _ in hkobjects = o }
        let addGlucoseSamples1Completion = expectation(description: "addGlucoseSamples1")
        // Authorized
        glucoseStore.addGlucoseSamples([sample1]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 1)
            }
            addGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
        XCTAssertEqual(1, hkobjects.count)
        hkobjects = []
        
        healthStore.authorizationStatus = .sharingDenied
        let addGlucoseSamples2Completion = expectation(description: "addGlucoseSamples2")
        // Denied
        glucoseStore.addGlucoseSamples([sample2]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 1)
            }
            addGlucoseSamples2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
        XCTAssertEqual(0, hkobjects.count)
        hkobjects = []

        healthStore.authorizationStatus = .sharingAuthorized
        let addGlucoseSamples3Completion = expectation(description: "addGlucoseSamples3")
        // Authorized
        glucoseStore.addGlucoseSamples([sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 1)
            }
            addGlucoseSamples3Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
        XCTAssertEqual(1, hkobjects.count)
        hkobjects = []

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample1)
                XCTAssertNotNil(samples[1].uuid)
                XCTAssertNil(samples[1].healthKitEligibleDate)
                assertEqualSamples(samples[1], self.sample3)
                XCTAssertNil(samples[2].uuid)
                XCTAssertNil(samples[2].healthKitEligibleDate)
                assertEqualSamples(samples[2], self.sample2)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }
    
    func testLatestGlucose() {
        XCTAssertNil(glucoseStore.latestGlucose)

        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                assertEqualSamples(samples[0], self.sample1)
                assertEqualSamples(samples[1], self.sample2)
                assertEqualSamples(samples[2], self.sample3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        XCTAssertNotNil(glucoseStore.latestGlucose)
        XCTAssertEqual(glucoseStore.latestGlucose?.startDate, sample2.date)
        XCTAssertEqual(glucoseStore.latestGlucose?.endDate, sample2.date)
        XCTAssertEqual(glucoseStore.latestGlucose?.quantity, sample2.quantity)
        XCTAssertEqual(glucoseStore.latestGlucose?.provenanceIdentifier, HKSource.default().bundleIdentifier)
        XCTAssertEqual(glucoseStore.latestGlucose?.isDisplayOnly, sample2.isDisplayOnly)
        XCTAssertEqual(glucoseStore.latestGlucose?.wasUserEntered, sample2.wasUserEntered)

        let purgeCachedGlucoseObjectsCompletion = expectation(description: "purgeCachedGlucoseObjects")
        glucoseStore.purgeCachedGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeCachedGlucoseObjectsCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        XCTAssertNil(glucoseStore.latestGlucose)
    }

    // MARK: - Modification

    func testAddGlucoseSamples() {
        let addGlucoseSamples1Completion = expectation(description: "addGlucoseSamples1")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3, sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                // Note: the HealthKit UUID is no longer updated before being returned as a result of addGlucoseSamples.
                XCTAssertNil(samples[0].uuid)
                XCTAssertNotNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample1)
                XCTAssertNil(samples[1].uuid)
                XCTAssertNotNil(samples[1].healthKitEligibleDate)
                assertEqualSamples(samples[1], self.sample2)
                XCTAssertNil(samples[2].uuid)
                XCTAssertNotNil(samples[2].healthKitEligibleDate)
                assertEqualSamples(samples[2], self.sample3)
            }
            addGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample1)
                XCTAssertNotNil(samples[1].uuid)
                XCTAssertNil(samples[1].healthKitEligibleDate)
                assertEqualSamples(samples[1], self.sample3)
                XCTAssertNotNil(samples[2].uuid)
                XCTAssertNil(samples[2].healthKitEligibleDate)
                assertEqualSamples(samples[2], self.sample2)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let addGlucoseSamples2Completion = expectation(description: "addGlucoseSamples2")
        glucoseStore.addGlucoseSamples([sample3, sample1, sample2]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            addGlucoseSamples2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples2Completion = expectation(description: "getGlucoseSamples2Completion")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
                XCTAssertNotNil(samples[0].uuid)
                XCTAssertNil(samples[0].healthKitEligibleDate)
                assertEqualSamples(samples[0], self.sample1)
                XCTAssertNotNil(samples[1].uuid)
                XCTAssertNil(samples[1].healthKitEligibleDate)
                assertEqualSamples(samples[1], self.sample3)
                XCTAssertNotNil(samples[2].uuid)
                XCTAssertNil(samples[2].healthKitEligibleDate)
                assertEqualSamples(samples[2], self.sample2)
            }
            getGlucoseSamples2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testAddGlucoseSamplesEmpty() {
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testAddGlucoseSamplesNotification() {
        delegateCompletion = expectation(description: "delegate")
        let glucoseSamplesDidChangeCompletion = expectation(description: "glucoseSamplesDidChange")
        let observer = NotificationCenter.default.addObserver(forName: GlucoseStore.glucoseSamplesDidChange, object: glucoseStore, queue: nil) { notification in
            glucoseSamplesDidChangeCompletion.fulfill()
        }

        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        wait(for: [glucoseSamplesDidChangeCompletion, delegateCompletion!, addGlucoseSamplesCompletion], timeout: 10, enforceOrder: true)

        NotificationCenter.default.removeObserver(observer)
        delegateCompletion = nil
    }

    // MARK: - Watch Synchronization

    func testSyncGlucoseSamples() {
        var syncGlucoseSamples: [StoredGlucoseSample] = []

        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getSyncGlucoseSamples1Completion = expectation(description: "getSyncGlucoseSamples1")
        glucoseStore.getSyncGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let objects):
                XCTAssertEqual(objects.count, 3)
                XCTAssertNotNil(objects[0].uuid)
                assertEqualSamples(objects[0], self.sample1)
                XCTAssertNotNil(objects[1].uuid)
                assertEqualSamples(objects[1], self.sample3)
                XCTAssertNotNil(objects[2].uuid)
                assertEqualSamples(objects[2], self.sample2)
                syncGlucoseSamples = objects
            }
            getSyncGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getSyncGlucoseSamples2Completion = expectation(description: "getSyncGlucoseSamples2")
        glucoseStore.getSyncGlucoseSamples(start: Date(timeIntervalSinceNow: -.minutes(5)), end: Date(timeIntervalSinceNow: -.minutes(3))) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let objects):
                XCTAssertEqual(objects.count, 1)
                XCTAssertNotNil(objects[0].uuid)
                assertEqualSamples(objects[0], self.sample3)
            }
            getSyncGlucoseSamples2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeCachedGlucoseObjectsCompletion = expectation(description: "purgeCachedGlucoseObjects")
        glucoseStore.purgeCachedGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeCachedGlucoseObjectsCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getSyncGlucoseSamples3Completion = expectation(description: "getSyncGlucoseSamples3")
        glucoseStore.getSyncGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            getSyncGlucoseSamples3Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let setSyncGlucoseSamplesCompletion = expectation(description: "setSyncGlucoseSamples")
        glucoseStore.setSyncGlucoseSamples(syncGlucoseSamples) { error in
            XCTAssertNil(error)
            setSyncGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getSyncGlucoseSamples4Completion = expectation(description: "getSyncGlucoseSamples4")
        glucoseStore.getSyncGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let objects):
                XCTAssertEqual(objects.count, 3)
                XCTAssertNotNil(objects[0].uuid)
                assertEqualSamples(objects[0], self.sample1)
                XCTAssertNotNil(objects[1].uuid)
                assertEqualSamples(objects[1], self.sample3)
                XCTAssertNotNil(objects[2].uuid)
                assertEqualSamples(objects[2], self.sample2)
                syncGlucoseSamples = objects
            }
            getSyncGlucoseSamples4Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    // MARK: - Cache Management

    func testEarliestCacheDate() {
        XCTAssertEqual(glucoseStore.earliestCacheDate.timeIntervalSinceNow, -.hours(1), accuracy: 1)
    }

    func testPurgeAllGlucoseSamples() {
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeAllGlucoseSamplesCompletion = expectation(description: "purgeAllGlucoseSamples")
        glucoseStore.purgeAllGlucoseSamples(healthKitPredicate: HKQuery.predicateForObjects(from: HKSource.default())) { error in
            XCTAssertNil(error)
            purgeAllGlucoseSamplesCompletion.fulfill()

        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples2Completion = expectation(description: "getGlucoseSamples2")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            getGlucoseSamples2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testPurgeExpiredGlucoseObjects() {
        let expiredSample = NewGlucoseSample(date: Date(timeIntervalSinceNow: -.hours(2)),
                                             quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 198.7),
                                             condition: nil,
                                             trend: nil,
                                             trendRate: nil,
                                             isDisplayOnly: false,
                                             wasUserEntered: false,
                                             syncIdentifier: "6AB8C7F3-A2CE-442F-98C4-3D0514626B5F",
                                             syncVersion: 3)

        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3, expiredSample]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 4)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamplesCompletion = expectation(description: "getGlucoseSamples")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            getGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testPurgeCachedGlucoseObjects() {
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples1Completion = expectation(description: "getGlucoseSamples1")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            getGlucoseSamples1Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeCachedGlucoseObjects1Completion = expectation(description: "purgeCachedGlucoseObjects1")
        glucoseStore.purgeCachedGlucoseObjects(before: Date(timeIntervalSinceNow: -.minutes(5))) { error in
            XCTAssertNil(error)
            purgeCachedGlucoseObjects1Completion.fulfill()

        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples2Completion = expectation(description: "getGlucoseSamples2")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 2)
            }
            getGlucoseSamples2Completion.fulfill()
        }
        waitForExpectations(timeout: 10)

        let purgeCachedGlucoseObjects2Completion = expectation(description: "purgeCachedGlucoseObjects2")
        glucoseStore.purgeCachedGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeCachedGlucoseObjects2Completion.fulfill()

        }
        waitForExpectations(timeout: 10)

        let getGlucoseSamples3Completion = expectation(description: "getGlucoseSamples3")
        glucoseStore.getGlucoseSamples() { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 0)
            }
            getGlucoseSamples3Completion.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testPurgeCachedGlucoseObjectsNotification() {
        let addGlucoseSamplesCompletion = expectation(description: "addGlucoseSamples")
        glucoseStore.addGlucoseSamples([sample1, sample2, sample3]) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let samples):
                XCTAssertEqual(samples.count, 3)
            }
            addGlucoseSamplesCompletion.fulfill()
        }
        waitForExpectations(timeout: 10)

        delegateCompletion = expectation(description: "delegate")
        let glucoseSamplesDidChangeCompletion = expectation(description: "glucoseSamplesDidChange")
        let observer = NotificationCenter.default.addObserver(forName: GlucoseStore.glucoseSamplesDidChange, object: glucoseStore, queue: nil) { notification in
            glucoseSamplesDidChangeCompletion.fulfill()
        }

        let purgeCachedGlucoseObjectsCompletion = expectation(description: "purgeCachedGlucoseObjects")
        glucoseStore.purgeCachedGlucoseObjects() { error in
            XCTAssertNil(error)
            purgeCachedGlucoseObjectsCompletion.fulfill()

        }
        wait(for: [glucoseSamplesDidChangeCompletion, delegateCompletion!, purgeCachedGlucoseObjectsCompletion], timeout: 10, enforceOrder: true)

        NotificationCenter.default.removeObserver(observer)
        delegateCompletion = nil
    }
}

fileprivate func assertEqualSamples(_ storedGlucoseSample: StoredGlucoseSample,
                                    _ newGlucoseSample: NewGlucoseSample,
                                    provenanceIdentifier: String = HKSource.default().bundleIdentifier,
                                    file: StaticString = #file,
                                    line: UInt = #line) {
    XCTAssertEqual(storedGlucoseSample.provenanceIdentifier, provenanceIdentifier, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.syncIdentifier, newGlucoseSample.syncIdentifier, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.syncVersion, newGlucoseSample.syncVersion, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.startDate, newGlucoseSample.date, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.quantity, newGlucoseSample.quantity, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.isDisplayOnly, newGlucoseSample.isDisplayOnly, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.wasUserEntered, newGlucoseSample.wasUserEntered, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.device, newGlucoseSample.device, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.condition, newGlucoseSample.condition, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.trend, newGlucoseSample.trend, file: file, line: line)
    XCTAssertEqual(storedGlucoseSample.trendRate, newGlucoseSample.trendRate, file: file, line: line)
}
