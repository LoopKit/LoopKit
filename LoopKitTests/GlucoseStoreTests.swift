//
//  GlucoseStoreTests.swift
//  LoopKitTests
//
//  Created by Darin Krauss on 12/30/19.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import CoreData
@testable import LoopKit

class GlucoseStoreQueryAnchorTests: XCTestCase {
    
    var rawValue: GlucoseStore.QueryAnchor.RawValue = [
        "modificationCounter": Int64(123)
    ]
    
    func testInitializerDefault() {
        let queryAnchor = GlucoseStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.modificationCounter, 0)
    }
    
    func testInitializerRawValue() {
        let queryAnchor = GlucoseStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.modificationCounter, 123)
    }
    
    func testInitializerRawValueMissingModificationCounter() {
        rawValue["modificationCounter"] = nil
        XCTAssertNil(GlucoseStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testInitializerRawValueInvalidModificationCounter() {
        rawValue["modificationCounter"] = "123"
        XCTAssertNil(GlucoseStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testRawValueWithDefault() {
        let rawValue = GlucoseStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(0))
    }
    
    func testRawValueWithNonDefault() {
        var queryAnchor = GlucoseStore.QueryAnchor()
        queryAnchor.modificationCounter = 123
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["modificationCounter"] as? Int64, Int64(123))
    }
    
}

class GlucoseStoreQueryTests: PersistenceControllerTestCase {
    
    var glucoseStore: GlucoseStore!
    var queryAnchor: GlucoseStore.QueryAnchor!
    var limit: Int!
    var observerQuery: HKObserverQueryMock!
    var healthStore: HKHealthStoreMock!

    override func setUp() {
        super.setUp()
        
        healthStore = HKHealthStoreMock()
        glucoseStore = GlucoseStore(healthStore: healthStore,
                                    cacheStore: cacheStore)
        
        let semaphore = DispatchSemaphore(value: 0)
        cacheStore.onReady { (error) in
            semaphore.signal()
        }
        semaphore.wait()
        queryAnchor = GlucoseStore.QueryAnchor()
        limit = Int.max
    }
    
    override func tearDown() {
        limit = nil
        queryAnchor = nil
        glucoseStore = nil
        healthStore.lastQuery = nil

        super.tearDown()
    }
    
    func testHKQueryAnchorPersistence() {
        
        var observerQuery: HKObserverQueryMock? = nil
        var anchoredObjectQuery: HKAnchoredObjectQueryMock? = nil

        glucoseStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            return observerQuery!
        }
        
        let authorizationCompletion = expectation(description: "authorization completion")
        glucoseStore.authorize { (result) in
            authorizationCompletion.fulfill()
        }
        
        waitForExpectations(timeout: 3)
        
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

        wait(for: [anchoredObjectQueryCreationExpectation], timeout: 3)
        
        // Trigger results handler for anchored object query
        let returnedAnchor = HKQueryAnchor(fromValue: 5)
        anchoredObjectQuery!.resultsHandler(anchoredObjectQuery!, [], [], returnedAnchor, nil)

        // Wait for observerQueryCompletionExpectation
        waitForExpectations(timeout: 3)

        XCTAssertNotNil(glucoseStore.queryAnchor)

        cacheStore.managedObjectContext.performAndWait {}
        
        // Create a new glucose store, and ensure it uses the last query anchor
        let newGlucoseStore = GlucoseStore(healthStore: healthStore, cacheStore: cacheStore)
        
        let newAuthorizationCompletion = expectation(description: "authorization completion")
        
        observerQuery = nil
        
        newGlucoseStore.createObserverQuery = { (sampleType, predicate, updateHandler) -> HKObserverQuery in
            observerQuery = HKObserverQueryMock(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
            return observerQuery!
        }

        newGlucoseStore.authorize { (result) in
            newAuthorizationCompletion.fulfill()
        }
        waitForExpectations(timeout: 3)
        
        anchoredObjectQuery = nil

        let newAnchoredObjectQueryCreationExpectation = expectation(description: "new anchored object query creation")
        newGlucoseStore.createAnchoredObjectQuery = { (sampleType, predicate, anchor, limit, resultsHandler) -> HKAnchoredObjectQuery in
            anchoredObjectQuery = HKAnchoredObjectQueryMock(type: sampleType, predicate: predicate, anchor: anchor, limit: limit, resultsHandler: resultsHandler)
            newAnchoredObjectQueryCreationExpectation.fulfill()
            return anchoredObjectQuery!
        }
        
        // This simulates a signal marking the arrival of new HK Data.
        observerQuery!.updateHandler(observerQuery!, {}, nil)
        
        wait(for: [newAnchoredObjectQueryCreationExpectation], timeout: 3)
        
        // Assert new glucose store is querying with the last anchor that our HealthKit mock returned
        XCTAssertEqual(returnedAnchor, anchoredObjectQuery?.anchor)
        
        anchoredObjectQuery!.resultsHandler(anchoredObjectQuery!, [], [], returnedAnchor, nil)
    }
    
    func testEmptyWithDefaultQueryAnchor() {
        let completion = expectation(description: "Completion")
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testEmptyWithMissingQueryAnchor() {
        queryAnchor = nil
        let completion = expectation(description: "Completion")

        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.modificationCounter = 1
        let completion = expectation(description: "Completion")

        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 1)
                XCTAssertEqual(data.count, 0)
            }
            completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDataWithUnusedQueryAnchor() {
        let completion = expectation(description: "Completion")
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addData(withSyncIdentifiers: syncIdentifiers)
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 3)
                for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                    XCTAssertEqual(data[index].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(data[index].syncVersion, index)
                }
            }
            completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDataWithStaleQueryAnchor() {
        let completion = expectation(description: "Completion")
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addData(withSyncIdentifiers: syncIdentifiers)
        
        queryAnchor.modificationCounter = 2
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 1)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(data[0].syncVersion, 2)
            }
            completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDataWithCurrentQueryAnchor() {
        let completion = expectation(description: "Completion")
        
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addData(withSyncIdentifiers: syncIdentifiers)
        
        queryAnchor.modificationCounter = 3
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 3)
                XCTAssertEqual(data.count, 0)
            }
            completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitZero() {
        let completion = expectation(description: "Completion")

        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        limit = 0

        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 0)
                XCTAssertEqual(data.count, 0)
            }
            completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitCoveredByData() {
        let completion = expectation(description: "Completion")

        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addData(withSyncIdentifiers: syncIdentifiers)
        
        limit = 2
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let data):
                XCTAssertEqual(anchor.modificationCounter, 2)
                XCTAssertEqual(data.count, 2)
                XCTAssertEqual(data[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(data[0].syncVersion, 0)
                XCTAssertEqual(data[1].syncIdentifier, syncIdentifiers[1])
                XCTAssertEqual(data[1].syncVersion, 1)
            }
            completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    private func addData(withSyncIdentifiers syncIdentifiers: [String]) {
        cacheStore.managedObjectContext.performAndWait {
            for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                let cachedGlucoseObject = CachedGlucoseObject(context: self.cacheStore.managedObjectContext)
                cachedGlucoseObject.uuid = UUID()
                cachedGlucoseObject.syncIdentifier = syncIdentifier
                cachedGlucoseObject.syncVersion = Int32(index)
                cachedGlucoseObject.value = 123
                cachedGlucoseObject.unitString = HKUnit.milligramsPerDeciliter.unitString
                cachedGlucoseObject.startDate = Date()
                cachedGlucoseObject.provenanceIdentifier = syncIdentifier
                self.cacheStore.save()
            }
        }
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }

}
