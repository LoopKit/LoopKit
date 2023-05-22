//
//  CarbStoreHKQueryTests.swift
//  LoopKitHostedTests
//
//  Created by Darin Krauss on 10/9/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class CarbStoreHKQueryTestsBase: PersistenceControllerTestCase {
    var healthStore: HKHealthStoreMock!
    var carbStore: CarbStore!
    var authorizationStatus: HKAuthorizationStatus = .notDetermined
    var hkSampleStore: HKSampleStoreCompositional!

    override func setUp() {
        super.setUp()

        healthStore = HKHealthStoreMock()
        healthStore.authorizationStatus = authorizationStatus

        let observationInterval: TimeInterval = .hours(1)

        hkSampleStore = HKSampleStoreCompositional(
            healthStore: healthStore,
            observeHealthKitSamplesFromCurrentApp: true,
            observeHealthKitSamplesFromOtherApps: false,
            type:HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryCarbohydrates)!,
            observationStart: Date().addingTimeInterval(-observationInterval),
            observationEnabled: true)

        hkSampleStore.testQueryStore = healthStore

        carbStore = CarbStore(healthKitSampleStore: hkSampleStore,
                              cacheStore: cacheStore,
                              cacheLength: .hours(24),
                              defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
                              observationInterval: observationInterval,
                              provenanceIdentifier: Bundle.main.bundleIdentifier!)

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            semaphore.signal()
        }
        semaphore.wait()
    }

    override func tearDown() {
        carbStore = nil
        healthStore = nil

        super.tearDown()
    }
    
}

class CarbStoreHKQueryTestsAuthorized: CarbStoreHKQueryTestsBase {
    override func setUp() {
        authorizationStatus = .sharingAuthorized
        super.setUp()
    }

    func testObserverQueryStartup() {
        // Check that an observer query is registered when authorization is already determined.
        XCTAssertFalse(hkSampleStore.authorizationRequired);

        let observerQueryCreated = expectation(description: "observer query created")

        hkSampleStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            let observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            observerQueryCreated.fulfill()
            return observerQuery
        }

        waitForExpectations(timeout: 2)
    }
}

class CarbStoreHKQueryTests: CarbStoreHKQueryTestsBase {
    func testHKQueryAnchorPersistence() {
        var observerQuery: HKObserverQueryMock? = nil
        var anchoredObjectQuery: HKAnchoredObjectQueryMock? = nil
        
        XCTAssert(hkSampleStore.authorizationRequired);
        XCTAssertNil(hkSampleStore.observerQuery);

        let observerQueryCreated = expectation(description: "observer query created")

        hkSampleStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            observerQueryCreated.fulfill()
            return observerQuery!
        }

        healthStore.authorizationStatus = .sharingAuthorized
        hkSampleStore.authorizationIsDetermined()

        waitForExpectations(timeout: 3)

        XCTAssertNotNil(observerQuery)

        let anchoredObjectQueryCreationExpectation = expectation(description: "anchored object query creation")
        hkSampleStore.createAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) -> HKAnchoredObjectQuery in
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

        wait(for: [anchoredObjectQueryCreationExpectation], timeout: 3)

        // Trigger results handler for anchored object query
        let returnedAnchor = HKQueryAnchor(fromValue: 5)
        anchoredObjectQuery!.resultsHandler(anchoredObjectQuery!, [], [], returnedAnchor, nil)

        // Wait for observerQueryCompletionExpectation
        waitForExpectations(timeout: 3)

        XCTAssertNotNil(hkSampleStore.queryAnchor)

        cacheStore.managedObjectContext.performAndWait {}

        // Create a new carb store, and ensure it uses the last query anchor

        let newSampleStore = HKSampleStoreCompositional(
            healthStore: healthStore,
            observeHealthKitSamplesFromCurrentApp: true,
            observeHealthKitSamplesFromOtherApps: false,
            type:HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryCarbohydrates)!,
            observationStart: Date().addingTimeInterval(0),
            observationEnabled: true)

        newSampleStore.testQueryStore = healthStore

        let newCarbStore = CarbStore(healthKitSampleStore: newSampleStore,
                                     cacheStore: cacheStore,
                                     cacheLength: .hours(24),
                                     defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
                                     observationInterval: .hours(1),
                                     provenanceIdentifier: Bundle.main.bundleIdentifier!)

        observerQuery = nil

        let newObserverQueryCreated = expectation(description: "new observer query created")
        newSampleStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            newObserverQueryCreated.fulfill()
            return observerQuery!
        }

        healthStore.authorizationStatus = .sharingAuthorized
        newSampleStore.authorizationIsDetermined()

        // Wait for observerQueryCompletionExpectation
        waitForExpectations(timeout: 3)

        anchoredObjectQuery = nil

        let newAnchoredObjectQueryCreationExpectation = expectation(description: "new anchored object query creation")
        newSampleStore.createAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) -> HKAnchoredObjectQuery in
            anchoredObjectQuery = HKAnchoredObjectQueryMock(type: sampleType, predicate: predicate, anchor: anchor, limit: limit, resultsHandler: resultsHandler)
            newAnchoredObjectQueryCreationExpectation.fulfill()
            return anchoredObjectQuery!
        }

        // This simulates a signal marking the arrival of new HK Data.
        observerQuery!.updateHandler(observerQuery!, {}, nil)

        wait(for: [newAnchoredObjectQueryCreationExpectation], timeout: 3)

        // Assert new carb store is querying with the last anchor that our HealthKit mock returned
        XCTAssertEqual(returnedAnchor, anchoredObjectQuery?.anchor)

        anchoredObjectQuery!.resultsHandler(anchoredObjectQuery!, [], [], returnedAnchor, nil)
    }
}
