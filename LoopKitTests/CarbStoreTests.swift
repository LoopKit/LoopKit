//
//  CarbStoreTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
import CoreData
@testable import LoopKit

class CarbStorePersistenceTests: PersistenceControllerTestCase, CarbStoreDelegate {
    
    var healthStore: HKHealthStoreMock!
    var carbStore: CarbStore!
    
    override func setUp() {
        super.setUp()
        
        healthStore = HKHealthStoreMock()
        carbStore = CarbStore(healthStore: healthStore, cacheStore: cacheStore)
        carbStore.testQueryStore = healthStore
        carbStore.delegate = self
    }
    
    override func tearDown() {
        carbStore.delegate = nil
        carbStore = nil
        healthStore = nil
        
        carbStoreHasUpdatedCarbDataHandler = nil
        
        super.tearDown()
    }
    
    // MARK: - CarbStoreDelegate
    
    var carbStoreHasUpdatedCarbDataHandler: ((_ : CarbStore) -> Void)?
    
    func carbStoreHasUpdatedCarbData(_ carbStore: CarbStore) {
        carbStoreHasUpdatedCarbDataHandler?(carbStore)
    }
    
    func carbStore(_ carbStore: CarbStore, didError error: CarbStore.CarbStoreError) {}
    
    // MARK: -
    
    func testAddCarbEntry() {
        let syncIdentifier = generateSyncIdentifier()
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3), syncIdentifier: syncIdentifier)
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        
        var handlerInvocation = 0
        
        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1
            
            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertGreaterThan(objects[0].modificationCounter, 0)
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }
        }
        
        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }
        
        wait(for: [addCarbEntryCompletion, addCarbEntryHandler], timeout: 2, enforceOrder: true)
    }
    
    func testAddAndReplaceCarbEntry() {
        let syncIdentifier = generateSyncIdentifier()
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3), syncIdentifier: syncIdentifier)
        let replaceCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: "Replace", absorptionTime: .hours(4))
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let replaceCarbEntryCompletion = expectation(description: "Replace carb entry completion")
        let replaceCarbEntryHandler = expectation(description: "Replace carb entry handler")
        
        var handlerInvocation = 0
        
        var lastUUID: UUID?
        var lastModificationCounter: Int64?
        
        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1
            
            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertGreaterThan(objects[0].modificationCounter, 0)
                    lastUUID = objects[0].uuid
                    lastModificationCounter = objects[0].modificationCounter
                    self.carbStore.replaceCarbEntry(StoredCarbEntry(managedObject: objects[0]), withEntry: replaceCarbEntry) { (result) in
                        replaceCarbEntryCompletion.fulfill()
                    }
                case 2:
                    replaceCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, replaceCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertNotEqual(objects[0].uuid!, lastUUID!)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 2)
                    XCTAssertGreaterThan(objects[0].modificationCounter, lastModificationCounter!)
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }
            
        }
        
        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }
        
        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, replaceCarbEntryCompletion, replaceCarbEntryHandler], timeout: 2, enforceOrder: true)
    }
    
    func testAddAndDeleteCarbEntry() {
        let syncIdentifier = generateSyncIdentifier()
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3), syncIdentifier: syncIdentifier)
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let deleteCarbEntryCompletion = expectation(description: "Delete carb entry completion")
        let deleteCarbEntryHandler = expectation(description: "Delete carb entry handler")
        
        var handlerInvocation = 0
        
        var lastUUID: UUID?
        var lastModificationCounter: Int64?
        
        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1
            
            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertGreaterThan(objects[0].modificationCounter, 0)
                    lastUUID = objects[0].uuid
                    lastModificationCounter = objects[0].modificationCounter
                    self.carbStore.deleteCarbEntry(StoredCarbEntry(managedObject: objects[0])) { (result) in
                        deleteCarbEntryCompletion.fulfill()
                    }
                case 2:
                    deleteCarbEntryHandler.fulfill()
                    let objects: [DeletedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].uuid!, lastUUID!)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertGreaterThan(objects[0].modificationCounter, lastModificationCounter!)
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }
            
        }
        
        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }
        
        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, deleteCarbEntryCompletion, deleteCarbEntryHandler], timeout: 2, enforceOrder: true)
    }
    
    func testAddAndReplaceAndDeleteCarbEntry() {
        let syncIdentifier = generateSyncIdentifier()
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3), syncIdentifier: syncIdentifier)
        let replaceCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: "Replace", absorptionTime: .hours(4))
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let replaceCarbEntryCompletion = expectation(description: "Replace carb entry completion")
        let replaceCarbEntryHandler = expectation(description: "Replace carb entry handler")
        let deleteCarbEntryCompletion = expectation(description: "Delete carb entry completion")
        let deleteCarbEntryHandler = expectation(description: "Delete carb entry handler")
        
        var handlerInvocation = 0
        
        var lastUUID: UUID?
        var lastModificationCounter: Int64?
        
        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1
            
            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertGreaterThan(objects[0].modificationCounter, 0)
                    lastUUID = objects[0].uuid
                    lastModificationCounter = objects[0].modificationCounter
                    self.carbStore.replaceCarbEntry(StoredCarbEntry(managedObject: objects[0]), withEntry: replaceCarbEntry) { (result) in
                        replaceCarbEntryCompletion.fulfill()
                    }
                case 2:
                    replaceCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertEqual(objects[0].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, replaceCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertNotEqual(objects[0].uuid!, lastUUID!)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 2)
                    XCTAssertGreaterThan(objects[0].modificationCounter, lastModificationCounter!)
                    lastUUID = objects[0].uuid
                    lastModificationCounter = objects[0].modificationCounter
                    self.carbStore.deleteCarbEntry(StoredCarbEntry(managedObject: objects[0])) { (result) in
                        deleteCarbEntryCompletion.fulfill()
                    }
                case 3:
                    deleteCarbEntryHandler.fulfill()
                    let objects: [DeletedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)
                    XCTAssertNil(objects[0].externalID)
                    XCTAssertEqual(objects[0].uploadState, .notUploaded)
                    XCTAssertEqual(objects[0].startDate, replaceCarbEntry.startDate)
                    XCTAssertNotNil(objects[0].uuid)
                    XCTAssertEqual(objects[0].uuid!, lastUUID!)
                    XCTAssertEqual(objects[0].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 2)
                    XCTAssertGreaterThan(objects[0].modificationCounter, lastModificationCounter!)
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }
            
        }
        
        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }
        
        wait(for: [addCarbEntryCompletion, addCarbEntryHandler, replaceCarbEntryCompletion, replaceCarbEntryHandler, deleteCarbEntryCompletion, deleteCarbEntryHandler], timeout: 2, enforceOrder: true)
    }
    
    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }

}

class CarbStoreQueryAnchorTests: XCTestCase {
    
    var rawValue: CarbStore.QueryAnchor.RawValue = [
        "deletedModificationCounter": Int64(123),
        "storedModificationCounter": Int64(456)
    ]
    
    func testInitializerDefault() {
        let queryAnchor = CarbStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.deletedModificationCounter, 0)
        XCTAssertEqual(queryAnchor.storedModificationCounter, 0)
    }
    
    func testInitializerRawValue() {
        let queryAnchor = CarbStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.deletedModificationCounter, 123)
        XCTAssertEqual(queryAnchor?.storedModificationCounter, 456)
    }
    
    func testInitializerRawValueMissingDeletedModificationCounter() {
        rawValue["deletedModificationCounter"] = nil
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testInitializerRawValueMissingStoredModificationCounter() {
        rawValue["storedModificationCounter"] = nil
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testInitializerRawValueInvalidDeletedModificationCounter() {
        rawValue["deletedModificationCounter"] = "123"
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testInitializerRawValueInvalidStoredModificationCounter() {
        rawValue["storedModificationCounter"] = "456"
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }
    
    func testRawValueWithDefault() {
        let rawValue = CarbStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 2)
        XCTAssertEqual(rawValue["deletedModificationCounter"] as? Int64, Int64(0))
        XCTAssertEqual(rawValue["storedModificationCounter"] as? Int64, Int64(0))
    }
    
    func testRawValueWithNonDefault() {
        var queryAnchor = CarbStore.QueryAnchor()
        queryAnchor.deletedModificationCounter = 123
        queryAnchor.storedModificationCounter = 456
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 2)
        XCTAssertEqual(rawValue["deletedModificationCounter"] as? Int64, Int64(123))
        XCTAssertEqual(rawValue["storedModificationCounter"] as? Int64, Int64(456))
    }
    
}

class CarbStoreQueryTests: PersistenceControllerTestCase {
    
    var carbStore: CarbStore!
    var completion: XCTestExpectation!
    var queryAnchor: CarbStore.QueryAnchor!
    var limit: Int!
    
    override func setUp() {
        super.setUp()
        
        carbStore = CarbStore(healthStore: HKHealthStoreMock(), cacheStore: cacheStore)
        completion = expectation(description: "Completion")
        queryAnchor = CarbStore.QueryAnchor()
        limit = Int.max
    }
    
    override func tearDown() {
        limit = nil
        queryAnchor = nil
        completion = nil
        carbStore = nil
        
        super.tearDown()
    }
    
    func testEmptyWithDefaultQueryAnchor() {
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 0)
                XCTAssertEqual(anchor.storedModificationCounter, 0)
                XCTAssertEqual(deleted.count, 0)
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testEmptyWithMissingQueryAnchor() {
        queryAnchor = nil
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 0)
                XCTAssertEqual(anchor.storedModificationCounter, 0)
                XCTAssertEqual(deleted.count, 0)
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.deletedModificationCounter = 1
        queryAnchor.storedModificationCounter = 2
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 1)
                XCTAssertEqual(anchor.storedModificationCounter, 2)
                XCTAssertEqual(deleted.count, 0)
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDeletedWithUnusedQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addDeleted(withSyncIdentifiers: syncIdentifiers)
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 3)
                XCTAssertEqual(anchor.storedModificationCounter, 0)
                XCTAssertEqual(deleted.count, 3)
                for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                    XCTAssertEqual(deleted[index].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(deleted[index].syncVersion, index)
                }
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDeletedWithStaleQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addDeleted(withSyncIdentifiers: syncIdentifiers)
        
        queryAnchor.deletedModificationCounter = 2
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 3)
                XCTAssertEqual(anchor.storedModificationCounter, 0)
                XCTAssertEqual(deleted.count, 1)
                XCTAssertEqual(deleted[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(deleted[0].syncVersion, 2)
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDeletedWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addDeleted(withSyncIdentifiers: syncIdentifiers)
        
        queryAnchor.deletedModificationCounter = 3
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 3)
                XCTAssertEqual(anchor.storedModificationCounter, 0)
                XCTAssertEqual(deleted.count, 0)
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testStoredWithUnusedQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addStored(withSyncIdentifiers: syncIdentifiers)
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 0)
                XCTAssertEqual(anchor.storedModificationCounter, 4)
                XCTAssertEqual(deleted.count, 0)
                XCTAssertEqual(stored.count, 4)
                for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                    XCTAssertEqual(stored[index].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(stored[index].syncVersion, index)
                }
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testStoredWithStaleQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addStored(withSyncIdentifiers: syncIdentifiers)
        
        queryAnchor.storedModificationCounter = 2
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 0)
                XCTAssertEqual(anchor.storedModificationCounter, 4)
                XCTAssertEqual(deleted.count, 0)
                XCTAssertEqual(stored.count, 2)
                XCTAssertEqual(stored[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(stored[0].syncVersion, 2)
                XCTAssertEqual(stored[1].syncIdentifier, syncIdentifiers[3])
                XCTAssertEqual(stored[1].syncVersion, 3)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testStoredWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addStored(withSyncIdentifiers: syncIdentifiers)
        
        queryAnchor.storedModificationCounter = 4
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 0)
                XCTAssertEqual(anchor.storedModificationCounter, 4)
                XCTAssertEqual(deleted.count, 0)
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDeletedAndStoredWithUnusedQueryAnchor() {
        let deletedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        let storedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addDeleted(withSyncIdentifiers: deletedSyncIdentifiers)
        addStored(withSyncIdentifiers: storedSyncIdentifiers)
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 3)
                XCTAssertEqual(anchor.storedModificationCounter, 7)
                XCTAssertEqual(deleted.count, 3)
                for (index, syncIdentifier) in deletedSyncIdentifiers.enumerated() {
                    XCTAssertEqual(deleted[index].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(deleted[index].syncVersion, index)
                }
                XCTAssertEqual(stored.count, 4)
                for (index, syncIdentifier) in storedSyncIdentifiers.enumerated() {
                    XCTAssertEqual(stored[index].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(stored[index].syncVersion, index)
                }
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDeletedAndStoredWithStaleQueryAnchor() {
        let deletedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        let storedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addDeleted(withSyncIdentifiers: deletedSyncIdentifiers)
        addStored(withSyncIdentifiers: storedSyncIdentifiers)
        
        queryAnchor.deletedModificationCounter = 2
        queryAnchor.storedModificationCounter = 5
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 3)
                XCTAssertEqual(anchor.storedModificationCounter, 7)
                XCTAssertEqual(deleted.count, 1)
                XCTAssertEqual(deleted[0].syncIdentifier, deletedSyncIdentifiers[2])
                XCTAssertEqual(deleted[0].syncVersion, 2)
                XCTAssertEqual(stored.count, 2)
                XCTAssertEqual(stored[0].syncIdentifier, storedSyncIdentifiers[2])
                XCTAssertEqual(stored[0].syncVersion, 2)
                XCTAssertEqual(stored[1].syncIdentifier, storedSyncIdentifiers[3])
                XCTAssertEqual(stored[1].syncVersion, 3)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    func testDeletedAndStoredWithCurrentQueryAnchor() {
        let deletedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        let storedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addDeleted(withSyncIdentifiers: deletedSyncIdentifiers)
        addStored(withSyncIdentifiers: storedSyncIdentifiers)
        
        queryAnchor.deletedModificationCounter = 3
        queryAnchor.storedModificationCounter = 7
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 3)
                XCTAssertEqual(anchor.storedModificationCounter, 7)
                XCTAssertEqual(deleted.count, 0)
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDeletedAndStoredWithLimitZero() {
        let deletedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        let storedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addDeleted(withSyncIdentifiers: deletedSyncIdentifiers)
        addStored(withSyncIdentifiers: storedSyncIdentifiers)

        limit = 0

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 0)
                XCTAssertEqual(anchor.storedModificationCounter, 0)
                XCTAssertEqual(deleted.count, 0)
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDeletedAndStoredWithLimitCoveredByDeleted() {
        let deletedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        let storedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addDeleted(withSyncIdentifiers: deletedSyncIdentifiers)
        addStored(withSyncIdentifiers: storedSyncIdentifiers)

        limit = 2

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 2)
                XCTAssertEqual(anchor.storedModificationCounter, 0)
                XCTAssertEqual(deleted.count, 2)
                XCTAssertEqual(deleted[0].syncIdentifier, deletedSyncIdentifiers[0])
                XCTAssertEqual(deleted[0].syncVersion, 0)
                XCTAssertEqual(deleted[1].syncIdentifier, deletedSyncIdentifiers[1])
                XCTAssertEqual(deleted[1].syncVersion, 1)
                XCTAssertEqual(stored.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDeletedAndStoredWithLimitCoveredByDeletedAndStored() {
        let deletedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        let storedSyncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]
        
        addDeleted(withSyncIdentifiers: deletedSyncIdentifiers)
        addStored(withSyncIdentifiers: storedSyncIdentifiers)
        
        limit = 5
        
        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let deleted, let stored):
                XCTAssertEqual(anchor.deletedModificationCounter, 3)
                XCTAssertEqual(anchor.storedModificationCounter, 5)
                XCTAssertEqual(deleted.count, 3)
                for (index, syncIdentifier) in deletedSyncIdentifiers.enumerated() {
                    XCTAssertEqual(deleted[index].syncIdentifier, syncIdentifier)
                    XCTAssertEqual(deleted[index].syncVersion, index)
                }
                XCTAssertEqual(stored.count, 2)
                XCTAssertEqual(stored[0].syncIdentifier, storedSyncIdentifiers[0])
                XCTAssertEqual(stored[0].syncVersion, 0)
                XCTAssertEqual(stored[1].syncIdentifier, storedSyncIdentifiers[1])
                XCTAssertEqual(stored[1].syncVersion, 1)
            }
            self.completion.fulfill()
        }
        
        wait(for: [completion], timeout: 2, enforceOrder: true)
    }
    
    private func addDeleted(withSyncIdentifiers syncIdentifiers: [String]) {
        cacheStore.managedObjectContext.performAndWait {
            for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                let deletedCarbObject = DeletedCarbObject(context: self.cacheStore.managedObjectContext)
                deletedCarbObject.startDate = Date()
                deletedCarbObject.syncIdentifier = syncIdentifier
                deletedCarbObject.syncVersion = Int32(index)
                self.cacheStore.save()
            }
        }
    }
    
    private func addStored(withSyncIdentifiers syncIdentifiers: [String]) {
        cacheStore.managedObjectContext.performAndWait {
            for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                let cachedCarbObject = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                cachedCarbObject.createdByCurrentApp = true
                cachedCarbObject.startDate = Date()
                cachedCarbObject.uuid = UUID()
                cachedCarbObject.syncIdentifier = syncIdentifier
                cachedCarbObject.syncVersion = Int32(index)
                self.cacheStore.save()
            }
        }
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }
    
}
