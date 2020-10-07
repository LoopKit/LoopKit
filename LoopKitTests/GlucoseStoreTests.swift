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

class GlucoseStoreCriticalEventLogTests: PersistenceControllerTestCase {
    var glucoseStore: GlucoseStore!
    var outputStream: MockOutputStream!
    var progress: Progress!
    
    override func setUp() {
        super.setUp()

        let samples = [StoredGlucoseSample(sampleUUID: UUID(uuidString: "28CF3948-0B3D-4B12-8BFE-14986B0E6784")!, syncIdentifier: "18CF3948-0B3D-4B12-8BFE-14986B0E6784", syncVersion: 1, startDate: dateFormatter.date(from: "2100-01-02T03:08:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 111), isDisplayOnly: false, wasUserEntered: false, provenanceIdentifier: "org.loopkit.Test.1"),
                       StoredGlucoseSample(sampleUUID: UUID(uuidString: "D86DEB61-68E9-464E-9DD5-96A9CB445FD3")!, syncIdentifier: "C86DEB61-68E9-464E-9DD5-96A9CB445FD3", syncVersion: 2, startDate: dateFormatter.date(from: "2100-01-02T03:10:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 112), isDisplayOnly: false, wasUserEntered: false, provenanceIdentifier: "org.loopkit.Test.2"),
                       StoredGlucoseSample(sampleUUID: UUID(uuidString: "3B03D96C-6F5D-4140-99CD-80C3E64D6010")!, syncIdentifier: "2B03D96C-6F5D-4140-99CD-80C3E64D6010", syncVersion: 3, startDate: dateFormatter.date(from: "2100-01-02T03:04:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 113), isDisplayOnly: false, wasUserEntered: false, provenanceIdentifier: "org.loopkit.Test.3"),
                       StoredGlucoseSample(sampleUUID: UUID(uuidString: "0F1C4F01-3558-4FB2-957E-FA1522C4735E")!, syncIdentifier: "FF1C4F01-3558-4FB2-957E-FA1522C4735E", syncVersion: 4, startDate: dateFormatter.date(from: "2100-01-02T03:06:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 114), isDisplayOnly: false, wasUserEntered: false, provenanceIdentifier: "org.loopkit.Test.4"),
                       StoredGlucoseSample(sampleUUID: UUID(uuidString: "81B699D7-0E8F-4B13-B7A1-E7751EB78E74")!, syncIdentifier: "71B699D7-0E8F-4B13-B7A1-E7751EB78E74", syncVersion: 5, startDate: dateFormatter.date(from: "2100-01-02T03:02:00Z")!, quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 115), isDisplayOnly: false, wasUserEntered: false, provenanceIdentifier: "org.loopkit.Test.5")]

        glucoseStore = GlucoseStore(healthStore: HKHealthStoreMock(), cacheStore: cacheStore)

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        glucoseStore.addGlucoseSamples(samples: samples) { error in
            XCTAssertNil(error)
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        outputStream = MockOutputStream()
        progress = Progress()
    }

    override func tearDown() {
        glucoseStore = nil

        super.tearDown()
    }
    
    func testExportProgressTotalUnitCount() {
        switch glucoseStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                         endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 3 * 1)
        }
    }
    
    func testExportProgressTotalUnitCountEmpty() {
        switch glucoseStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                                         endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 0)
        }
    }

    func testExport() {
        XCTAssertNil(glucoseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                         endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                         to: outputStream,
                                         progress: progress))
        XCTAssertEqual(outputStream.string, """
[
{"isDisplayOnly":false,"modificationCounter":1,"provenanceIdentifier":"org.loopkit.Test.1","startDate":"2100-01-02T03:08:00.000Z","syncIdentifier":"18CF3948-0B3D-4B12-8BFE-14986B0E6784","syncVersion":1,"unitString":"mg/dL","uploadState":0,"uuid":"28CF3948-0B3D-4B12-8BFE-14986B0E6784","value":111,"wasUserEntered":false},
{"isDisplayOnly":false,"modificationCounter":3,"provenanceIdentifier":"org.loopkit.Test.3","startDate":"2100-01-02T03:04:00.000Z","syncIdentifier":"2B03D96C-6F5D-4140-99CD-80C3E64D6010","syncVersion":3,"unitString":"mg/dL","uploadState":0,"uuid":"3B03D96C-6F5D-4140-99CD-80C3E64D6010","value":113,"wasUserEntered":false},
{"isDisplayOnly":false,"modificationCounter":4,"provenanceIdentifier":"org.loopkit.Test.4","startDate":"2100-01-02T03:06:00.000Z","syncIdentifier":"FF1C4F01-3558-4FB2-957E-FA1522C4735E","syncVersion":4,"unitString":"mg/dL","uploadState":0,"uuid":"0F1C4F01-3558-4FB2-957E-FA1522C4735E","value":114,"wasUserEntered":false}
]
"""
        )
        XCTAssertEqual(progress.completedUnitCount, 3 * 1)
    }

    func testExportEmpty() {
        XCTAssertNil(glucoseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                         endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!,
                                         to: outputStream,
                                         progress: progress))
        XCTAssertEqual(outputStream.string, "[]")
        XCTAssertEqual(progress.completedUnitCount, 0)
    }

    func testExportCancelled() {
        progress.cancel()
        XCTAssertEqual(glucoseStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                           endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                           to: outputStream,
                                           progress: progress) as? CriticalEventLogError, CriticalEventLogError.cancelled)
    }

    private let dateFormatter = ISO8601DateFormatter()
}
