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
    var completion: XCTestExpectation!
    var queryAnchor: GlucoseStore.QueryAnchor!
    var limit: Int!
    
    override func setUp() {
        super.setUp()
        
        glucoseStore = GlucoseStore(healthStore: HKHealthStoreMock(), cacheStore: cacheStore)
        completion = expectation(description: "Completion")
        queryAnchor = GlucoseStore.QueryAnchor()
        limit = Int.max
    }
    
    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        glucoseStore = nil
        
        super.tearDown()
    }
    
    func testEmptyWithDefaultQueryAnchor() {
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
    
    func testEmptyWithMissingQueryAnchor() {
        queryAnchor = nil
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
    
    func testEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.modificationCounter = 1
        
        glucoseStore.executeGlucoseQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
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
    
    func testDataWithUnusedQueryAnchor() {
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
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDataWithStaleQueryAnchor() {
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
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDataWithCurrentQueryAnchor() {
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
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitZero() {
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
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitCoveredByData() {
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
            self.completion.fulfill()
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
