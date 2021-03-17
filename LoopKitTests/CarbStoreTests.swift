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
        carbStore = CarbStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: 0,
            provenanceIdentifier: Bundle.main.bundleIdentifier!)
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
    
    func testGetCarbEntriesAfterAdd() {
        let firstCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(timeIntervalSinceNow: -1), foodType: "First", absorptionTime: .hours(5))
        let secondCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 20), startDate: Date(), foodType: "Second", absorptionTime: .hours(3))
        let thirdCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 30), startDate: Date(timeIntervalSinceNow: 1), foodType: "Third", absorptionTime: .minutes(30))
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        carbStore.addCarbEntry(firstCarbEntry) { (_) in
            DispatchQueue.main.async {
                self.carbStore.addCarbEntry(secondCarbEntry) { (_) in
                    DispatchQueue.main.async {
                        self.carbStore.addCarbEntry(thirdCarbEntry) { (_) in
                            DispatchQueue.main.async {
                                self.carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                                    getCarbEntriesCompletion.fulfill()
                                    switch result {
                                    case .failure(let error):
                                        XCTFail("Unexpected failure: \(error)")
                                    case .success(let entries):
                                        XCTAssertEqual(entries.count, 3)

                                        // First
                                        XCTAssertNotNil(entries[0].uuid)
                                        XCTAssertEqual(entries[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                                        XCTAssertNotNil(entries[0].syncIdentifier)
                                        XCTAssertEqual(entries[0].syncVersion, 1)
                                        XCTAssertEqual(entries[0].startDate, firstCarbEntry.startDate)
                                        XCTAssertEqual(entries[0].quantity, firstCarbEntry.quantity)
                                        XCTAssertEqual(entries[0].foodType, firstCarbEntry.foodType)
                                        XCTAssertEqual(entries[0].absorptionTime, firstCarbEntry.absorptionTime)
                                        XCTAssertEqual(entries[0].createdByCurrentApp, true)
                                        XCTAssertEqual(entries[0].userCreatedDate, firstCarbEntry.date)
                                        XCTAssertNil(entries[0].userUpdatedDate)

                                        // Second
                                        XCTAssertNotNil(entries[1].uuid)
                                        XCTAssertEqual(entries[1].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                                        XCTAssertNotNil(entries[1].syncIdentifier)
                                        XCTAssertEqual(entries[1].syncVersion, 1)
                                        XCTAssertEqual(entries[1].startDate, secondCarbEntry.startDate)
                                        XCTAssertEqual(entries[1].quantity, secondCarbEntry.quantity)
                                        XCTAssertEqual(entries[1].foodType, secondCarbEntry.foodType)
                                        XCTAssertEqual(entries[1].absorptionTime, secondCarbEntry.absorptionTime)
                                        XCTAssertEqual(entries[1].createdByCurrentApp, true)
                                        XCTAssertEqual(entries[1].userCreatedDate, secondCarbEntry.date)
                                        XCTAssertNil(entries[1].userUpdatedDate)

                                        // Third
                                        XCTAssertNotNil(entries[2].uuid)
                                        XCTAssertEqual(entries[2].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                                        XCTAssertNotNil(entries[2].syncIdentifier)
                                        XCTAssertEqual(entries[2].syncVersion, 1)
                                        XCTAssertEqual(entries[2].startDate, thirdCarbEntry.startDate)
                                        XCTAssertEqual(entries[2].quantity, thirdCarbEntry.quantity)
                                        XCTAssertEqual(entries[2].foodType, thirdCarbEntry.foodType)
                                        XCTAssertEqual(entries[2].absorptionTime, thirdCarbEntry.absorptionTime)
                                        XCTAssertEqual(entries[2].createdByCurrentApp, true)
                                        XCTAssertEqual(entries[2].userCreatedDate, thirdCarbEntry.date)
                                        XCTAssertNil(entries[2].userUpdatedDate)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        wait(for: [getCarbEntriesCompletion], timeout: 2, enforceOrder: true)
    }

    // MARK: -

    func testAddCarbEntry() {
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3))
        let addHealthStoreHandler = expectation(description: "Add health store handler")
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        var handlerInvocation = 0

        var addUUID: UUID?
        var addSyncIdentifier: String?

        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)

            let sample = objects.first as! HKQuantitySample

            XCTAssertEqual(sample.absorptionTime, addCarbEntry.absorptionTime)
            XCTAssertEqual(sample.foodType, addCarbEntry.foodType)
            XCTAssertEqual(sample.quantity, addCarbEntry.quantity)
            XCTAssertEqual(sample.startDate, addCarbEntry.startDate)
            XCTAssertNotNil(sample.syncIdentifier)
            XCTAssertEqual(sample.syncVersion, 1)
            XCTAssertEqual(sample.userCreatedDate, addCarbEntry.date)
            XCTAssertNil(sample.userUpdatedDate)

            addUUID = sample.uuid
            addSyncIdentifier = sample.syncIdentifier

            addHealthStoreHandler.fulfill()
        })

        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1

            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)

                    // Added object
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uuid, addUUID)
                    XCTAssertEqual(objects[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[0].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].userCreatedDate, addCarbEntry.date)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNil(objects[0].supercededDate)
                    XCTAssertGreaterThan(objects[0].anchorKey, 0)

                    DispatchQueue.main.async {
                        carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                            getCarbEntriesCompletion.fulfill()
                            switch result {
                            case .failure(let error):
                                XCTFail("Unexpected failure: \(error)")
                            case .success(let entries):
                                XCTAssertEqual(entries.count, 1)

                                // Added sample
                                XCTAssertEqual(entries[0].uuid, addUUID)
                                XCTAssertEqual(entries[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                                XCTAssertEqual(entries[0].syncIdentifier, addSyncIdentifier)
                                XCTAssertEqual(entries[0].syncVersion, 1)
                                XCTAssertEqual(entries[0].startDate, addCarbEntry.startDate)
                                XCTAssertEqual(entries[0].quantity, addCarbEntry.quantity)
                                XCTAssertEqual(entries[0].foodType, addCarbEntry.foodType)
                                XCTAssertEqual(entries[0].absorptionTime, addCarbEntry.absorptionTime)
                                XCTAssertEqual(entries[0].createdByCurrentApp, true)
                                XCTAssertEqual(entries[0].userCreatedDate, addCarbEntry.date)
                                XCTAssertNil(entries[0].userUpdatedDate)
                            }
                        }
                    }
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }
        }

        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }

        wait(for: [addHealthStoreHandler, addCarbEntryCompletion, addCarbEntryHandler, getCarbEntriesCompletion], timeout: 10, enforceOrder: true)
    }

    func testAddAndReplaceCarbEntry() {
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3))
        let replaceCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: "Replace", absorptionTime: .hours(4))
        let addHealthStoreHandler = expectation(description: "Add health store handler")
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let updateHealthStoreHandler = expectation(description: "Update health store handler")
        let updateCarbEntryCompletion = expectation(description: "Update carb entry completion")
        let updateCarbEntryHandler = expectation(description: "Update carb entry handler")
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        var handlerInvocation = 0

        var addUUID: UUID?
        var addSyncIdentifier: String?
        var addAnchorKey: Int64?
        var updateUUID: UUID?

        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)

            let sample = objects.first as! HKQuantitySample

            XCTAssertEqual(sample.absorptionTime, addCarbEntry.absorptionTime)
            XCTAssertEqual(sample.foodType, addCarbEntry.foodType)
            XCTAssertEqual(sample.quantity, addCarbEntry.quantity)
            XCTAssertEqual(sample.startDate, addCarbEntry.startDate)
            XCTAssertNotNil(sample.syncIdentifier)
            XCTAssertEqual(sample.syncVersion, 1)
            XCTAssertEqual(sample.userCreatedDate, addCarbEntry.date)
            XCTAssertNil(sample.userUpdatedDate)

            addUUID = sample.uuid
            addSyncIdentifier = sample.syncIdentifier

            addHealthStoreHandler.fulfill()
        })

        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1

            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)

                    // Added object
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uuid, addUUID)
                    XCTAssertEqual(objects[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[0].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].userCreatedDate, addCarbEntry.date)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNil(objects[0].supercededDate)
                    XCTAssertGreaterThan(objects[0].anchorKey, 0)

                    addAnchorKey = objects[0].anchorKey

                    self.healthStore.setSaveHandler({ (objects, success, error) in
                        XCTAssertEqual(1, objects.count)

                        let sample = objects.first as! HKQuantitySample

                        XCTAssertNotEqual(sample.uuid, addUUID)
                        XCTAssertEqual(sample.absorptionTime, replaceCarbEntry.absorptionTime)
                        XCTAssertEqual(sample.foodType, replaceCarbEntry.foodType)
                        XCTAssertEqual(sample.quantity, replaceCarbEntry.quantity)
                        XCTAssertEqual(sample.startDate, replaceCarbEntry.startDate)
                        XCTAssertEqual(sample.syncIdentifier, addSyncIdentifier)
                        XCTAssertEqual(sample.syncVersion, 2)
                        XCTAssertEqual(sample.userCreatedDate, addCarbEntry.date)
                        XCTAssertEqual(sample.userUpdatedDate, replaceCarbEntry.date)

                        updateUUID = sample.uuid

                        updateHealthStoreHandler.fulfill()
                    })

                    self.carbStore.replaceCarbEntry(StoredCarbEntry(managedObject: objects[0]), withEntry: replaceCarbEntry) { (result) in
                        updateCarbEntryCompletion.fulfill()
                    }
                case 2:
                    updateCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all().sorted { $0.syncVersion! < $1.syncVersion! }
                    XCTAssertEqual(objects.count, 2)

                    // Added object, superceded
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uuid, addUUID)
                    XCTAssertEqual(objects[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[0].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].userCreatedDate, addCarbEntry.date)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNotNil(objects[0].supercededDate)
                    XCTAssertEqual(objects[0].anchorKey, addAnchorKey)

                    // Updated object
                    XCTAssertEqual(objects[1].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertEqual(objects[1].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, replaceCarbEntry.startDate)
                    XCTAssertEqual(objects[1].uuid, updateUUID)
                    XCTAssertEqual(objects[1].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[1].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 2)
                    XCTAssertEqual(objects[1].userCreatedDate, addCarbEntry.date)
                    XCTAssertEqual(objects[1].userUpdatedDate, replaceCarbEntry.date)
                    XCTAssertNil(objects[1].userDeletedDate)
                    XCTAssertEqual(objects[1].operation, .update)
                    XCTAssertNotNil(objects[1].addedDate)
                    XCTAssertNil(objects[1].supercededDate)
                    XCTAssertGreaterThan(objects[1].anchorKey, addAnchorKey!)

                    DispatchQueue.main.async {
                        carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                            getCarbEntriesCompletion.fulfill()
                            switch result {
                            case .failure(let error):
                                XCTFail("Unexpected failure: \(error)")
                            case .success(let entries):
                                XCTAssertEqual(entries.count, 1)

                                // Updated sample
                                XCTAssertEqual(entries[0].uuid, updateUUID)
                                XCTAssertEqual(entries[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                                XCTAssertEqual(entries[0].syncIdentifier, addSyncIdentifier)
                                XCTAssertEqual(entries[0].syncVersion, 2)
                                XCTAssertEqual(entries[0].startDate, replaceCarbEntry.startDate)
                                XCTAssertEqual(entries[0].quantity, replaceCarbEntry.quantity)
                                XCTAssertEqual(entries[0].foodType, replaceCarbEntry.foodType)
                                XCTAssertEqual(entries[0].absorptionTime, replaceCarbEntry.absorptionTime)
                                XCTAssertEqual(entries[0].createdByCurrentApp, true)
                                XCTAssertEqual(entries[0].userCreatedDate, addCarbEntry.date)
                                XCTAssertEqual(entries[0].userUpdatedDate, replaceCarbEntry.date)
                            }
                        }
                    }
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }
        }

        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }

        wait(for: [addHealthStoreHandler, addCarbEntryCompletion, addCarbEntryHandler, updateHealthStoreHandler, updateCarbEntryCompletion, updateCarbEntryHandler, getCarbEntriesCompletion], timeout: 10, enforceOrder: true)
    }

    func testAddAndDeleteCarbEntry() {
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3))
        let addHealthStoreHandler = expectation(description: "Add health store handler")
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let deleteHealthStoreHandler = expectation(description: "Delete health store handler")
        let deleteCarbEntryCompletion = expectation(description: "Delete carb entry completion")
        let deleteCarbEntryHandler = expectation(description: "Delete carb entry handler")
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        var handlerInvocation = 0

        var addUUID: UUID?
        var addSyncIdentifier: String?
        var addAnchorKey: Int64?

        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)

            let sample = objects.first as! HKQuantitySample

            XCTAssertEqual(sample.absorptionTime, addCarbEntry.absorptionTime)
            XCTAssertEqual(sample.foodType, addCarbEntry.foodType)
            XCTAssertEqual(sample.quantity, addCarbEntry.quantity)
            XCTAssertEqual(sample.startDate, addCarbEntry.startDate)
            XCTAssertNotNil(sample.syncIdentifier)
            XCTAssertEqual(sample.syncVersion, 1)
            XCTAssertEqual(sample.userCreatedDate, addCarbEntry.date)
            XCTAssertNil(sample.userUpdatedDate)

            addUUID = sample.uuid
            addSyncIdentifier = sample.syncIdentifier

            addHealthStoreHandler.fulfill()
        })

        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1

            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)

                    // Added object
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uuid, addUUID)
                    XCTAssertEqual(objects[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[0].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].userCreatedDate, addCarbEntry.date)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNil(objects[0].supercededDate)
                    XCTAssertGreaterThan(objects[0].anchorKey, 0)

                    addUUID = objects[0].uuid
                    addSyncIdentifier = objects[0].syncIdentifier
                    addAnchorKey = objects[0].anchorKey

                    self.healthStore.setDeletedObjectsHandler({ (objectType, predicate, success, count, error) in
                        XCTAssertEqual(objectType, HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates))
                        XCTAssertEqual(predicate.predicateFormat, "UUID == \(addUUID!)")

                        deleteHealthStoreHandler.fulfill()
                    })

                    self.carbStore.deleteCarbEntry(StoredCarbEntry(managedObject: objects[0])) { (result) in
                        deleteCarbEntryCompletion.fulfill()
                    }
                case 2:
                    deleteCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 2)

                    // Added object, superceded
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uuid, addUUID)
                    XCTAssertEqual(objects[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[0].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].userCreatedDate, addCarbEntry.date)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNotNil(objects[0].supercededDate)
                    XCTAssertEqual(objects[0].anchorKey, addAnchorKey)

                    // Deleted object
                    XCTAssertEqual(objects[1].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertEqual(objects[1].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, addCarbEntry.startDate)
                    XCTAssertNil(objects[1].uuid)
                    XCTAssertEqual(objects[1].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[1].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 1)
                    XCTAssertEqual(objects[1].userCreatedDate, addCarbEntry.date)
                    XCTAssertNil(objects[1].userUpdatedDate)
                    XCTAssertNotNil(objects[1].userDeletedDate)
                    XCTAssertEqual(objects[1].operation, .delete)
                    XCTAssertNotNil(objects[1].addedDate)
                    XCTAssertNil(objects[1].supercededDate)
                    XCTAssertGreaterThan(objects[1].anchorKey, addAnchorKey!)

                    DispatchQueue.main.async {
                        carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                            getCarbEntriesCompletion.fulfill()
                            switch result {
                            case .failure(let error):
                                XCTFail("Unexpected failure: \(error)")
                            case .success(let entries):
                                XCTAssertEqual(entries.count, 0)
                            }
                        }
                    }
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }

        }

        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }

        wait(for: [addHealthStoreHandler, addCarbEntryCompletion, addCarbEntryHandler, deleteHealthStoreHandler, deleteCarbEntryCompletion, deleteCarbEntryHandler, getCarbEntriesCompletion], timeout: 10, enforceOrder: true)
    }

    func testAddAndReplaceAndDeleteCarbEntry() {
        let addCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: "Add", absorptionTime: .hours(3))
        let replaceCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: "Replace", absorptionTime: .hours(4))
        let addHealthStoreHandler = expectation(description: "Add health store handler")
        let addCarbEntryCompletion = expectation(description: "Add carb entry completion")
        let addCarbEntryHandler = expectation(description: "Add carb entry handler")
        let updateHealthStoreHandler = expectation(description: "Update health store handler")
        let updateCarbEntryCompletion = expectation(description: "Update carb entry completion")
        let updateCarbEntryHandler = expectation(description: "Update carb entry handler")
        let deleteHealthStoreHandler = expectation(description: "Delete health store handler")
        let deleteCarbEntryCompletion = expectation(description: "Delete carb entry completion")
        let deleteCarbEntryHandler = expectation(description: "Delete carb entry handler")
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        var handlerInvocation = 0

        var addUUID: UUID?
        var addSyncIdentifier: String?
        var addAnchorKey: Int64?
        var updateUUID: UUID?
        var updateAnchorKey: Int64?

        healthStore.setSaveHandler({ (objects, success, error) in
            XCTAssertEqual(1, objects.count)

            let sample = objects.first as! HKQuantitySample

            XCTAssertEqual(sample.absorptionTime, addCarbEntry.absorptionTime)
            XCTAssertEqual(sample.foodType, addCarbEntry.foodType)
            XCTAssertEqual(sample.quantity, addCarbEntry.quantity)
            XCTAssertEqual(sample.startDate, addCarbEntry.startDate)
            XCTAssertNotNil(sample.syncIdentifier)
            XCTAssertEqual(sample.syncVersion, 1)
            XCTAssertEqual(sample.userCreatedDate, addCarbEntry.date)
            XCTAssertNil(sample.userUpdatedDate)

            addUUID = sample.uuid
            addSyncIdentifier = sample.syncIdentifier

            addHealthStoreHandler.fulfill()
        })

        carbStoreHasUpdatedCarbDataHandler = { (carbStore) in
            handlerInvocation += 1

            self.cacheStore.managedObjectContext.performAndWait {
                switch handlerInvocation {
                case 1:
                    addCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(objects.count, 1)

                    // Added object
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uuid, addUUID)
                    XCTAssertEqual(objects[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[0].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].userCreatedDate, addCarbEntry.date)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNil(objects[0].supercededDate)
                    XCTAssertGreaterThan(objects[0].anchorKey, 0)

                    addAnchorKey = objects[0].anchorKey

                    self.healthStore.setSaveHandler({ (objects, success, error) in
                        XCTAssertEqual(1, objects.count)

                        let sample = objects.first as! HKQuantitySample

                        XCTAssertNotEqual(sample.uuid, addUUID)
                        XCTAssertEqual(sample.absorptionTime, replaceCarbEntry.absorptionTime)
                        XCTAssertEqual(sample.foodType, replaceCarbEntry.foodType)
                        XCTAssertEqual(sample.quantity, replaceCarbEntry.quantity)
                        XCTAssertEqual(sample.startDate, replaceCarbEntry.startDate)
                        XCTAssertEqual(sample.syncIdentifier, addSyncIdentifier)
                        XCTAssertEqual(sample.syncVersion, 2)
                        XCTAssertEqual(sample.userCreatedDate, addCarbEntry.date)
                        XCTAssertEqual(sample.userUpdatedDate, replaceCarbEntry.date)

                        updateUUID = sample.uuid

                        updateHealthStoreHandler.fulfill()
                    })

                    self.carbStore.replaceCarbEntry(StoredCarbEntry(managedObject: objects[0]), withEntry: replaceCarbEntry) { (result) in
                        updateCarbEntryCompletion.fulfill()
                    }
                case 2:
                    updateCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all().sorted { $0.syncVersion! < $1.syncVersion! }
                    XCTAssertEqual(objects.count, 2)

                    // Added object, superceded
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uuid, addUUID)
                    XCTAssertEqual(objects[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[0].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].userCreatedDate, addCarbEntry.date)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNotNil(objects[0].supercededDate)
                    XCTAssertEqual(objects[0].anchorKey, addAnchorKey)

                    // Updated object
                    XCTAssertEqual(objects[1].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertEqual(objects[1].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, replaceCarbEntry.startDate)
                    XCTAssertEqual(objects[1].uuid, updateUUID)
                    XCTAssertEqual(objects[1].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[1].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 2)
                    XCTAssertEqual(objects[1].userCreatedDate, addCarbEntry.date)
                    XCTAssertEqual(objects[1].userUpdatedDate, replaceCarbEntry.date)
                    XCTAssertNil(objects[1].userDeletedDate)
                    XCTAssertEqual(objects[1].operation, .update)
                    XCTAssertNotNil(objects[1].addedDate)
                    XCTAssertNil(objects[1].supercededDate)
                    XCTAssertGreaterThan(objects[1].anchorKey, addAnchorKey!)

                    updateAnchorKey = objects[1].anchorKey

                    self.healthStore.setDeletedObjectsHandler({ (objectType, predicate, success, count, error) in
                        XCTAssertEqual(objectType, HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates))
                        XCTAssertEqual(predicate.predicateFormat, "UUID == \(updateUUID!)")

                        deleteHealthStoreHandler.fulfill()
                    })

                    self.carbStore.deleteCarbEntry(StoredCarbEntry(managedObject: objects[1])) { (result) in
                        deleteCarbEntryCompletion.fulfill()
                    }
                case 3:
                    deleteCarbEntryHandler.fulfill()
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all().sorted { $0.syncVersion! < $1.syncVersion! }
                    XCTAssertEqual(objects.count, 3)

                    // Added object, superceded
                    XCTAssertEqual(objects[0].absorptionTime, addCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[0].createdByCurrentApp, true)
                    XCTAssertEqual(objects[0].foodType, addCarbEntry.foodType)
                    XCTAssertEqual(objects[0].grams, addCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[0].startDate, addCarbEntry.startDate)
                    XCTAssertEqual(objects[0].uuid, addUUID)
                    XCTAssertEqual(objects[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[0].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[0].syncVersion, 1)
                    XCTAssertEqual(objects[0].userCreatedDate, addCarbEntry.date)
                    XCTAssertNil(objects[0].userUpdatedDate)
                    XCTAssertNil(objects[0].userDeletedDate)
                    XCTAssertEqual(objects[0].operation, .create)
                    XCTAssertNotNil(objects[0].addedDate)
                    XCTAssertNotNil(objects[0].supercededDate)
                    XCTAssertEqual(objects[0].anchorKey, addAnchorKey)

                    // Updated object, superceded
                    XCTAssertEqual(objects[1].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[1].createdByCurrentApp, true)
                    XCTAssertEqual(objects[1].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[1].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[1].startDate, replaceCarbEntry.startDate)
                    XCTAssertEqual(objects[1].uuid, updateUUID)
                    XCTAssertEqual(objects[1].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[1].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[1].syncVersion, 2)
                    XCTAssertEqual(objects[1].userCreatedDate, addCarbEntry.date)
                    XCTAssertEqual(objects[1].userUpdatedDate, replaceCarbEntry.date)
                    XCTAssertNil(objects[1].userDeletedDate)
                    XCTAssertEqual(objects[1].operation, .update)
                    XCTAssertNotNil(objects[1].addedDate)
                    XCTAssertNotNil(objects[1].supercededDate)
                    XCTAssertEqual(objects[1].anchorKey, updateAnchorKey)

                    // Deleted object
                    XCTAssertEqual(objects[2].absorptionTime, replaceCarbEntry.absorptionTime)
                    XCTAssertEqual(objects[2].createdByCurrentApp, true)
                    XCTAssertEqual(objects[2].foodType, replaceCarbEntry.foodType)
                    XCTAssertEqual(objects[2].grams, replaceCarbEntry.quantity.doubleValue(for: .gram()))
                    XCTAssertEqual(objects[2].startDate, replaceCarbEntry.startDate)
                    XCTAssertNil(objects[2].uuid)
                    XCTAssertEqual(objects[2].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                    XCTAssertEqual(objects[2].syncIdentifier, addSyncIdentifier)
                    XCTAssertEqual(objects[2].syncVersion, 2)
                    XCTAssertEqual(objects[2].userCreatedDate, addCarbEntry.date)
                    XCTAssertEqual(objects[2].userUpdatedDate, replaceCarbEntry.date)
                    XCTAssertNotNil(objects[2].userDeletedDate)
                    XCTAssertEqual(objects[2].operation, .delete)
                    XCTAssertNotNil(objects[2].addedDate)
                    XCTAssertNil(objects[2].supercededDate)
                    XCTAssertGreaterThan(objects[2].anchorKey, updateAnchorKey!)

                    DispatchQueue.main.async {
                        carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                            getCarbEntriesCompletion.fulfill()
                            switch result {
                            case .failure(let error):
                                XCTFail("Unexpected failure: \(error)")
                            case .success(let entries):
                                XCTAssertEqual(entries.count, 0)
                            }
                        }
                    }
                default:
                    XCTFail("Unexpected handler invocation")
                }
            }

        }

        carbStore.addCarbEntry(addCarbEntry) { (result) in
            addCarbEntryCompletion.fulfill()
        }

        wait(for: [addHealthStoreHandler, addCarbEntryCompletion, addCarbEntryHandler, updateHealthStoreHandler, updateCarbEntryCompletion, updateCarbEntryHandler, deleteHealthStoreHandler, deleteCarbEntryCompletion, deleteCarbEntryHandler, getCarbEntriesCompletion], timeout: 10, enforceOrder: true)
    }

    // MARK: -

    func testGetSyncCarbObjects() {
        let firstCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(timeIntervalSinceNow: -1), foodType: "First", absorptionTime: .hours(5))
        let secondCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 20), startDate: Date(), foodType: "Second", absorptionTime: .hours(3))
        let thirdCarbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 30), startDate: Date(timeIntervalSinceNow: 1), foodType: "Third", absorptionTime: .minutes(30))
        let getSyncCarbObjectsCompletion = expectation(description: "Get sync carb objects completion")

        carbStore.addCarbEntry(firstCarbEntry) { (_) in
            DispatchQueue.main.async {
                self.carbStore.addCarbEntry(secondCarbEntry) { (_) in
                    DispatchQueue.main.async {
                        self.carbStore.addCarbEntry(thirdCarbEntry) { (_) in
                            DispatchQueue.main.async {
                                self.carbStore.getSyncCarbObjects(start: Date().addingTimeInterval(-.minutes(1))) { result in
                                    getSyncCarbObjectsCompletion.fulfill()
                                    switch result {
                                    case .failure(let error):
                                        XCTFail("Unexpected failure: \(error)")
                                    case .success(let objects):
                                        XCTAssertEqual(objects.count, 3)

                                        // First
                                        XCTAssertEqual(objects[0].absorptionTime, firstCarbEntry.absorptionTime)
                                        XCTAssertEqual(objects[0].createdByCurrentApp, true)
                                        XCTAssertEqual(objects[0].foodType, firstCarbEntry.foodType)
                                        XCTAssertEqual(objects[0].grams, firstCarbEntry.quantity.doubleValue(for: .gram()))
                                        XCTAssertEqual(objects[0].startDate, firstCarbEntry.startDate)
                                        XCTAssertNotNil(objects[0].uuid)
                                        XCTAssertEqual(objects[0].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                                        XCTAssertNotNil(objects[0].syncIdentifier)
                                        XCTAssertEqual(objects[0].syncVersion, 1)
                                        XCTAssertEqual(objects[0].userCreatedDate, firstCarbEntry.date)
                                        XCTAssertNil(objects[0].userUpdatedDate)
                                        XCTAssertNil(objects[0].userDeletedDate)
                                        XCTAssertEqual(objects[0].operation, .create)
                                        XCTAssertNotNil(objects[0].addedDate)
                                        XCTAssertNil(objects[0].supercededDate)

                                        // Second
                                        XCTAssertEqual(objects[1].absorptionTime, secondCarbEntry.absorptionTime)
                                        XCTAssertEqual(objects[1].createdByCurrentApp, true)
                                        XCTAssertEqual(objects[1].foodType, secondCarbEntry.foodType)
                                        XCTAssertEqual(objects[1].grams, secondCarbEntry.quantity.doubleValue(for: .gram()))
                                        XCTAssertEqual(objects[1].startDate, secondCarbEntry.startDate)
                                        XCTAssertNotNil(objects[1].uuid)
                                        XCTAssertEqual(objects[1].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                                        XCTAssertNotNil(objects[1].syncIdentifier)
                                        XCTAssertEqual(objects[1].syncVersion, 1)
                                        XCTAssertEqual(objects[1].userCreatedDate, secondCarbEntry.date)
                                        XCTAssertNil(objects[1].userUpdatedDate)
                                        XCTAssertNil(objects[1].userDeletedDate)
                                        XCTAssertEqual(objects[1].operation, .create)
                                        XCTAssertNotNil(objects[1].addedDate)
                                        XCTAssertNil(objects[1].supercededDate)

                                        // Third
                                        XCTAssertEqual(objects[2].absorptionTime, thirdCarbEntry.absorptionTime)
                                        XCTAssertEqual(objects[2].createdByCurrentApp, true)
                                        XCTAssertEqual(objects[2].foodType, thirdCarbEntry.foodType)
                                        XCTAssertEqual(objects[2].grams, thirdCarbEntry.quantity.doubleValue(for: .gram()))
                                        XCTAssertEqual(objects[2].startDate, thirdCarbEntry.startDate)
                                        XCTAssertNotNil(objects[2].uuid)
                                        XCTAssertEqual(objects[2].provenanceIdentifier, Bundle.main.bundleIdentifier!)
                                        XCTAssertNotNil(objects[2].syncIdentifier)
                                        XCTAssertEqual(objects[2].syncVersion, 1)
                                        XCTAssertEqual(objects[2].userCreatedDate, thirdCarbEntry.date)
                                        XCTAssertNil(objects[2].userUpdatedDate)
                                        XCTAssertNil(objects[2].userDeletedDate)
                                        XCTAssertEqual(objects[2].operation, .create)
                                        XCTAssertNotNil(objects[2].addedDate)
                                        XCTAssertNil(objects[2].supercededDate)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        wait(for: [getSyncCarbObjectsCompletion], timeout: 2, enforceOrder: true)
    }

    func testSetSyncCarbObjects() {
        let carbEntry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(timeIntervalSinceNow: -1), foodType: "First", absorptionTime: .hours(5))
        let syncCarbObjects = [SyncCarbObject(absorptionTime: .hours(5),
                                              createdByCurrentApp: true,
                                              foodType: "Pizza",
                                              grams: 45,
                                              startDate: Date(timeIntervalSinceNow: -30),
                                              uuid: UUID(),
                                              provenanceIdentifier: "com.loopkit.Loop",
                                              syncIdentifier: UUID().uuidString,
                                              syncVersion: 4,
                                              userCreatedDate: Date(timeIntervalSinceNow: -35),
                                              userUpdatedDate: Date(timeIntervalSinceNow: -34),
                                              userDeletedDate: nil,
                                              operation: .update,
                                              addedDate: Date(timeIntervalSinceNow: -34),
                                              supercededDate: nil),
                               SyncCarbObject(absorptionTime: .hours(3),
                                              createdByCurrentApp: false,
                                              foodType: "Pasta",
                                              grams: 25,
                                              startDate: Date(timeIntervalSinceNow: -15),
                                              uuid: UUID(),
                                              provenanceIdentifier: "com.abc.Example",
                                              syncIdentifier: UUID().uuidString,
                                              syncVersion: 1,
                                              userCreatedDate: Date(timeIntervalSinceNow: -16),
                                              userUpdatedDate: nil,
                                              userDeletedDate: nil,
                                              operation: .create,
                                              addedDate: Date(timeIntervalSinceNow: -16),
                                              supercededDate: nil),
                               SyncCarbObject(absorptionTime: .minutes(30),
                                              createdByCurrentApp: true,
                                              foodType: "Sugar",
                                              grams: 15,
                                              startDate: Date(timeIntervalSinceNow: 0),
                                              uuid: UUID(),
                                              provenanceIdentifier: "com.loopkit.Loop",
                                              syncIdentifier: UUID().uuidString,
                                              syncVersion: 1,
                                              userCreatedDate: Date(timeIntervalSinceNow: -1),
                                              userUpdatedDate: nil,
                                              userDeletedDate: nil,
                                              operation: .create,
                                              addedDate: Date(timeIntervalSinceNow: -1),
                                              supercededDate: nil)
        ]
        let getCarbEntriesCompletion = expectation(description: "Get carb entries completion")

        // Add a carb entry first, that will be purged when setSyncCarbObjects is invoked
        carbStore.addCarbEntry(carbEntry) { (_) in
            DispatchQueue.main.async {
                self.carbStore.setSyncCarbObjects(syncCarbObjects) { (error) in
                    XCTAssertNil(error)
                    DispatchQueue.main.async {
                        self.carbStore.getCarbEntries(start: Date().addingTimeInterval(-.minutes(1))) { result in
                            getCarbEntriesCompletion.fulfill()
                            switch result {
                            case .failure(let error):
                                XCTFail("Unexpected failure: \(error)")
                            case .success(let entries):
                                XCTAssertEqual(entries.count, 3)
                                for index in 0..<3 {
                                    XCTAssertEqual(entries[index].uuid, syncCarbObjects[index].uuid)
                                    XCTAssertEqual(entries[index].provenanceIdentifier, syncCarbObjects[index].provenanceIdentifier)
                                    XCTAssertEqual(entries[index].syncIdentifier, syncCarbObjects[index].syncIdentifier)
                                    XCTAssertEqual(entries[index].syncVersion, syncCarbObjects[index].syncVersion)
                                    XCTAssertEqual(entries[index].startDate, syncCarbObjects[index].startDate)
                                    XCTAssertEqual(entries[index].quantity, syncCarbObjects[index].quantity)
                                    XCTAssertEqual(entries[index].foodType, syncCarbObjects[index].foodType)
                                    XCTAssertEqual(entries[index].absorptionTime, syncCarbObjects[index].absorptionTime)
                                    XCTAssertEqual(entries[index].createdByCurrentApp, syncCarbObjects[index].createdByCurrentApp)
                                    XCTAssertEqual(entries[index].userCreatedDate, syncCarbObjects[index].userCreatedDate)
                                    XCTAssertEqual(entries[index].userCreatedDate, syncCarbObjects[index].userCreatedDate)
                                }
                            }
                        }
                    }
                }
            }
        }

        wait(for: [getCarbEntriesCompletion], timeout: 2, enforceOrder: true)
    }

    // MARK: -

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }

}

class CarbStoreQueryAnchorTests: XCTestCase {

    var rawValue: CarbStore.QueryAnchor.RawValue = [
        "anchorKey": Int64(123)
    ]

    func testInitializerDefault() {
        let queryAnchor = CarbStore.QueryAnchor()
        XCTAssertEqual(queryAnchor.anchorKey, 0)
    }

    func testInitializerRawValue() {
        let queryAnchor = CarbStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.anchorKey, 123)
    }

    func testInitializerRawValueMissingAnchorKey() {
        rawValue["anchorKey"] = nil
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }

    func testInitializerRawValueInvalidAnchorKey() {
        rawValue["anchorKey"] = "123"
        XCTAssertNil(CarbStore.QueryAnchor(rawValue: rawValue))
    }

    func testInitializerRawValueIgnoresDeprecatedStoredModificationCounter() {
        rawValue["storedModificationCounter"] = Int64(456)
        let queryAnchor = CarbStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.anchorKey, 123)
    }

    func testInitializerRawValueUsesDeprecatedStoredModificationCounter() {
        rawValue["anchorKey"] = nil
        rawValue["storedModificationCounter"] = Int64(456)
        let queryAnchor = CarbStore.QueryAnchor(rawValue: rawValue)
        XCTAssertNotNil(queryAnchor)
        XCTAssertEqual(queryAnchor?.anchorKey, 456)
    }

    func testRawValueWithDefault() {
        let rawValue = CarbStore.QueryAnchor().rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["anchorKey"] as? Int64, Int64(0))
    }

    func testRawValueWithNonDefault() {
        var queryAnchor = CarbStore.QueryAnchor()
        queryAnchor.anchorKey = 123
        let rawValue = queryAnchor.rawValue
        XCTAssertEqual(rawValue.count, 1)
        XCTAssertEqual(rawValue["anchorKey"] as? Int64, Int64(123))
    }

}

class CarbStoreQueryTests: PersistenceControllerTestCase {
    
    var carbStore: CarbStore!
    var completion: XCTestExpectation!
    var queryAnchor: CarbStore.QueryAnchor!
    var limit: Int!
    
    override func setUp() {
        super.setUp()
        
        carbStore = CarbStore(
            healthStore: HKHealthStoreMock(),
            cacheStore: cacheStore,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: 0,
            provenanceIdentifier: Bundle.main.bundleIdentifier!)
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
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 0)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
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
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 0)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testEmptyWithNonDefaultQueryAnchor() {
        queryAnchor.anchorKey = 1

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 1)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithUnusedQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 3)
                XCTAssertEqual(created.count, 1)
                XCTAssertEqual(created[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(created[0].syncVersion, 0)
                XCTAssertEqual(updated.count, 1)
                XCTAssertEqual(updated[0].syncIdentifier, syncIdentifiers[1])
                XCTAssertEqual(updated[0].syncVersion, 1)
                XCTAssertEqual(deleted.count, 1)
                XCTAssertEqual(deleted[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(deleted[0].syncVersion, 2)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithStaleQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.anchorKey = 2

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 3)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 1)
                XCTAssertEqual(deleted[0].syncIdentifier, syncIdentifiers[2])
                XCTAssertEqual(deleted[0].syncVersion, 2)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithCurrentQueryAnchor() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        queryAnchor.anchorKey = 3

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 3)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitZero() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        limit = 0

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 0)
                XCTAssertEqual(created.count, 0)
                XCTAssertEqual(updated.count, 0)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    func testDataWithLimitCoveredByData() {
        let syncIdentifiers = [generateSyncIdentifier(), generateSyncIdentifier(), generateSyncIdentifier()]

        addData(withSyncIdentifiers: syncIdentifiers)

        limit = 2

        carbStore.executeCarbQuery(fromQueryAnchor: queryAnchor, limit: limit) { result in
            switch result {
            case .failure(let error):
                XCTFail("Unexpected failure: \(error)")
            case .success(let anchor, let created, let updated, let deleted):
                XCTAssertEqual(anchor.anchorKey, 2)
                XCTAssertEqual(created.count, 1)
                XCTAssertEqual(created[0].syncIdentifier, syncIdentifiers[0])
                XCTAssertEqual(created[0].syncVersion, 0)
                XCTAssertEqual(updated.count, 1)
                XCTAssertEqual(updated[0].syncIdentifier, syncIdentifiers[1])
                XCTAssertEqual(updated[0].syncVersion, 1)
                XCTAssertEqual(deleted.count, 0)
            }
            self.completion.fulfill()
        }

        wait(for: [completion], timeout: 2, enforceOrder: true)
    }

    private func addData(withSyncIdentifiers syncIdentifiers: [String]) {
        cacheStore.managedObjectContext.performAndWait {
            for (index, syncIdentifier) in syncIdentifiers.enumerated() {
                let cachedCarbObject = CachedCarbObject(context: self.cacheStore.managedObjectContext)
                cachedCarbObject.createdByCurrentApp = true
                cachedCarbObject.startDate = Date()
                cachedCarbObject.uuid = UUID()
                cachedCarbObject.syncIdentifier = syncIdentifier
                cachedCarbObject.syncVersion = index
                cachedCarbObject.operation = Operation(rawValue: index % Operation.allCases.count)!
                cachedCarbObject.addedDate = Date()
                self.cacheStore.save()
            }
        }
    }

    private func generateSyncIdentifier() -> String {
        return UUID().uuidString
    }
    
}

class CarbStoreCriticalEventLogTests: PersistenceControllerTestCase {
    var carbStore: CarbStore!
    var outputStream: MockOutputStream!
    var progress: Progress!
    
    override func setUp() {
        super.setUp()

        let objects = [SyncCarbObject(absorptionTime: nil, createdByCurrentApp: true, foodType: nil, grams: 11, startDate: dateFormatter.date(from: "2100-01-02T03:08:00Z")!, uuid: nil, provenanceIdentifier: nil, syncIdentifier: nil, syncVersion: nil, userCreatedDate: nil, userUpdatedDate: nil, userDeletedDate: nil, operation: .create, addedDate: dateFormatter.date(from: "2100-01-02T03:08:00Z")!, supercededDate: nil),
                       SyncCarbObject(absorptionTime: nil, createdByCurrentApp: true, foodType: nil, grams: 12, startDate: dateFormatter.date(from: "2100-01-02T03:10:00Z")!, uuid: nil, provenanceIdentifier: nil, syncIdentifier: nil, syncVersion: nil, userCreatedDate: nil, userUpdatedDate: nil, userDeletedDate: nil, operation: .create, addedDate: dateFormatter.date(from: "2100-01-02T03:10:00Z")!, supercededDate: nil),
                       SyncCarbObject(absorptionTime: nil, createdByCurrentApp: true, foodType: nil, grams: 13, startDate: dateFormatter.date(from: "2100-01-02T03:04:00Z")!, uuid: nil, provenanceIdentifier: nil, syncIdentifier: nil, syncVersion: nil, userCreatedDate: nil, userUpdatedDate: nil, userDeletedDate: nil, operation: .create, addedDate: dateFormatter.date(from: "2100-01-02T02:04:00Z")!, supercededDate: dateFormatter.date(from: "2100-01-02T03:04:00Z")!),
                       SyncCarbObject(absorptionTime: nil, createdByCurrentApp: true, foodType: nil, grams: 14, startDate: dateFormatter.date(from: "2100-01-02T03:06:00Z")!, uuid: nil, provenanceIdentifier: nil, syncIdentifier: nil, syncVersion: nil, userCreatedDate: nil, userUpdatedDate: nil, userDeletedDate: nil, operation: .create, addedDate: dateFormatter.date(from: "2100-01-02T03:06:00Z")!, supercededDate: nil),
                       SyncCarbObject(absorptionTime: nil, createdByCurrentApp: true, foodType: nil, grams: 15, startDate: dateFormatter.date(from: "2100-01-02T03:02:00Z")!, uuid: nil, provenanceIdentifier: nil, syncIdentifier: nil, syncVersion: nil, userCreatedDate: nil, userUpdatedDate: nil, userDeletedDate: nil, operation: .create, addedDate: dateFormatter.date(from: "2100-01-02T03:02:00Z")!, supercededDate: nil)]

        carbStore = CarbStore(
            healthStore: HKHealthStoreMock(),
            cacheStore: cacheStore,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: 0,
            provenanceIdentifier: Bundle.main.bundleIdentifier!)

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        carbStore.setSyncCarbObjects(objects) { error in
            XCTAssertNil(error)
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        outputStream = MockOutputStream()
        progress = Progress()
    }

    override func tearDown() {
        carbStore = nil

        super.tearDown()
    }
    
    func testExportProgressTotalUnitCount() {
        switch carbStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                                      endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 3 * 1)
        }
    }
    
    func testExportProgressTotalUnitCountEmpty() {
        switch carbStore.exportProgressTotalUnitCount(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                                      endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!) {
        case .failure(let error):
            XCTFail("Unexpected failure: \(error)")
        case .success(let progressTotalUnitCount):
            XCTAssertEqual(progressTotalUnitCount, 0)
        }
    }

    func testExport() {
        XCTAssertNil(carbStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                      endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                      to: outputStream,
                                      progress: progress))
        XCTAssertEqual(outputStream.string, """
[
{"addedDate":"2100-01-02T03:08:00.000Z","anchorKey":1,"createdByCurrentApp":true,"grams":11,"operation":0,"startDate":"2100-01-02T03:08:00.000Z"},
{"addedDate":"2100-01-02T02:04:00.000Z","anchorKey":3,"createdByCurrentApp":true,"grams":13,"operation":0,"startDate":"2100-01-02T03:04:00.000Z","supercededDate":"2100-01-02T03:04:00.000Z"},
{"addedDate":"2100-01-02T03:06:00.000Z","anchorKey":4,"createdByCurrentApp":true,"grams":14,"operation":0,"startDate":"2100-01-02T03:06:00.000Z"}
]
"""
        )
        XCTAssertEqual(progress.completedUnitCount, 3 * 1)
    }

    func testExportEmpty() {
        XCTAssertNil(carbStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:00:00Z")!,
                                      endDate: dateFormatter.date(from: "2100-01-02T03:01:00Z")!,
                                      to: outputStream,
                                      progress: progress))
        XCTAssertEqual(outputStream.string, "[]")
        XCTAssertEqual(progress.completedUnitCount, 0)
    }

    func testExportCancelled() {
        progress.cancel()
        XCTAssertEqual(carbStore.export(startDate: dateFormatter.date(from: "2100-01-02T03:03:00Z")!,
                                        endDate: dateFormatter.date(from: "2100-01-02T03:09:00Z")!,
                                        to: outputStream,
                                        progress: progress) as? CriticalEventLogError, CriticalEventLogError.cancelled)
    }

    private let dateFormatter = ISO8601DateFormatter()
}
