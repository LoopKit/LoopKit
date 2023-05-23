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
    var mockHealthStore: HKHealthStoreMock!
    var carbStore: CarbStore!
    var authorizationStatus: HKAuthorizationStatus = .notDetermined
    var hkSampleStore: HealthKitSampleStore!

    override func setUp() {
        super.setUp()

        mockHealthStore = HKHealthStoreMock()
        mockHealthStore.authorizationStatus = authorizationStatus

        hkSampleStore = HealthKitSampleStore(healthStore: mockHealthStore, type: HealthKitSampleStore.carbType)

        hkSampleStore.observerQueryType = MockHKObserverQuery.self
        hkSampleStore.anchoredObjectQueryType = MockHKAnchoredObjectQuery.self

        carbStore = CarbStore(healthKitSampleStore: hkSampleStore,
                              cacheStore: cacheStore,
                              cacheLength: .hours(24),
                              defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
                              provenanceIdentifier: Bundle.main.bundleIdentifier!)

        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            semaphore.signal()
        }
        semaphore.wait()
    }

    override func tearDown() {
        carbStore = nil
        mockHealthStore = nil

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

        mockHealthStore.observerQueryStartedExpectation = expectation(description: "observer query started")

        waitForExpectations(timeout: 2)

        XCTAssertNotNil(mockHealthStore.observerQuery)
    }
}

class CarbStoreHKQueryTests: CarbStoreHKQueryTestsBase {
    func testHKQueryAnchorPersistence() {
        XCTAssert(hkSampleStore.authorizationRequired);
        XCTAssertNil(hkSampleStore.observerQuery);

        mockHealthStore.observerQueryStartedExpectation = expectation(description: "observer query started")

        mockHealthStore.authorizationStatus = .sharingAuthorized
        hkSampleStore.authorizationIsDetermined()

        waitForExpectations(timeout: 3)

        XCTAssertNotNil(mockHealthStore.observerQuery)

        mockHealthStore.anchorQueryStartedExpectation = expectation(description: "anchored object query started")

        let observerQueryCompletionExpectation = expectation(description: "observer query completion")

        let observerQueryCompletionHandler = {
            observerQueryCompletionExpectation.fulfill()
        }

        let mockObserverQuery = mockHealthStore.observerQuery as! MockHKObserverQuery

        // This simulates a signal marking the arrival of new HK Data.
        mockObserverQuery.updateHandler?(mockObserverQuery, observerQueryCompletionHandler, nil)

        wait(for: [mockHealthStore.anchorQueryStartedExpectation!])

        let currentAnchor = HKQueryAnchor(fromValue: 5)

        let mockAnchoredObjectQuery = mockHealthStore.anchoredObjectQuery as! MockHKAnchoredObjectQuery
        mockAnchoredObjectQuery.resultsHandler?(mockAnchoredObjectQuery, [], [], currentAnchor, nil)

        // Wait for observerQueryCompletionExpectation
        waitForExpectations(timeout: 3)

        XCTAssertNotNil(hkSampleStore.queryAnchor)

        cacheStore.managedObjectContext.performAndWait {}

        // Create a new carb store, and ensure it uses the last query anchor

        let newSampleStore = HealthKitSampleStore(healthStore: mockHealthStore, type: HealthKitSampleStore.carbType)
        newSampleStore.observerQueryType = MockHKObserverQuery.self
        newSampleStore.anchoredObjectQueryType = MockHKAnchoredObjectQuery.self


        let _ = CarbStore(healthKitSampleStore: newSampleStore,
                                     cacheStore: cacheStore,
                                     cacheLength: .hours(24),
                                     defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
                                     provenanceIdentifier: Bundle.main.bundleIdentifier!)


        mockHealthStore.observerQueryStartedExpectation = expectation(description: "new observer query started")

        mockHealthStore.authorizationStatus = .sharingAuthorized
        newSampleStore.authorizationIsDetermined()

        // Wait for observerQueryCompletionExpectation
        waitForExpectations(timeout: 3)

        mockHealthStore.anchorQueryStartedExpectation = expectation(description: "new anchored object query started")

        let mockObserverQuery2 = mockHealthStore.observerQuery as! MockHKObserverQuery

        // This simulates a signal marking the arrival of new HK Data.
        mockObserverQuery2.updateHandler?(mockObserverQuery2, {}, nil)

        // Wait for anchorQueryStartedExpectation
        waitForExpectations(timeout: 3)

        // Assert new carb store is querying with the last anchor that our HealthKit mock returned
        let mockAnchoredObjectQuery2 = mockHealthStore.anchoredObjectQuery as! MockHKAnchoredObjectQuery
        XCTAssertEqual(currentAnchor, mockAnchoredObjectQuery2.anchor)


        mockAnchoredObjectQuery2.resultsHandler?(mockAnchoredObjectQuery2, [], [], currentAnchor, nil)
    }
}
