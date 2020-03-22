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

class CarbStoreTests: PersistenceControllerTestCase, CarbStoreSyncDelegate {

    var carbStore: CarbStore!
    var healthStore: HKHealthStoreMock!

    override func setUp() {
        super.setUp()

        healthStore = HKHealthStoreMock()
        carbStore = CarbStore(healthStore: healthStore, cacheStore: cacheStore)
        carbStore.testQueryStore = healthStore
        carbStore.syncDelegate = self
    }

    override func tearDown() {
        carbStore.syncDelegate = nil
        carbStore = nil
        healthStore = nil

        uploadMessages = []
        deleteMessages = []
        uploadHandler = nil
        deleteHandler = nil

        super.tearDown()
    }

    // MARK: - CarbStoreSyncDelegate

    var uploadMessages: [(entries: [StoredCarbEntry], completion: ([StoredCarbEntry]) -> Void)] = []

    var uploadHandler: ((_: [StoredCarbEntry], _: ([StoredCarbEntry]) -> Void) -> Void)?

    func carbStore(_ carbStore: CarbStore, hasEntriesNeedingUpload entries: [StoredCarbEntry], completion: @escaping ([StoredCarbEntry]) -> Void) {
        uploadMessages.append((entries: entries, completion: completion))
        uploadHandler?(entries, completion)
    }

    var deleteMessages: [(entries: [DeletedCarbEntry], completion: ([DeletedCarbEntry]) -> Void)] = []

    var deleteHandler: ((_: [DeletedCarbEntry], _: ([DeletedCarbEntry]) -> Void) -> Void)?

    func carbStore(_ carbStore: CarbStore, hasDeletedEntries entries: [DeletedCarbEntry], completion: @escaping ([DeletedCarbEntry]) -> Void) {
        deleteMessages.append((entries: entries, completion: completion))
        deleteHandler?(entries, completion)
    }

    // MARK: -

    /// Adds a new entry, validates its uploading/uploaded transition
    func testAddAndSyncSuccessful() {
        let entry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let addCarb = expectation(description: "Add carb entry")
        let uploading = expectation(description: "Sync delegate: upload")
        let uploaded = expectation(description: "Sync delegate: completed")

        // 2. assert sync delegate called
        uploadHandler = { (entries, completion) in
            XCTAssertEqual(1, entries.count)

            // 3. assert entered in db as uploading
            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                XCTAssertEqual(1, objects.count)
                XCTAssertEqual(.uploading, objects.first!.uploadState)
            }
            uploading.fulfill()

            var entry = entries.first!
            entry.externalID = "1234"
            entry.isUploaded = true
            completion([entry])

            // 4. call delegate completion
            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                // 5. assert entered in db as uploaded
                XCTAssertEqual(.uploaded, objects.first!.uploadState)
                uploaded.fulfill()
            }
        }

        // 1. Add carb
        carbStore.addCarbEntry(entry) { (result) in
            addCarb.fulfill()
        }

        wait(for: [addCarb, uploading, uploaded], timeout: 2, enforceOrder: true)
    }

    /// Adds a new entry, validates its uploading/notUploaded transition
    func testAddAndSyncFailed() {
        let entry = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let addCarb = expectation(description: "Add carb entry")
        let uploading = expectation(description: "Sync delegate: upload")
        let uploaded = expectation(description: "Sync delegate: completed")

        // 2. assert sync delegate called
        uploadHandler = { (entries, completion) in
            XCTAssertEqual(1, entries.count)

            // 3. assert entered in db as uploading
            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                XCTAssertEqual(1, objects.count)
                XCTAssertEqual(.uploading, objects.first!.uploadState)
            }
            uploading.fulfill()

            completion(entries)  // Not uploaded

            // 4. call delegate completion
            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                // 5. assert entered in db as not uploaded
                XCTAssertEqual(.notUploaded, objects.first!.uploadState)

                uploaded.fulfill()
            }
        }

        // 1. Add carb
        carbStore.addCarbEntry(entry) { (result) in
            addCarb.fulfill()
        }

        wait(for: [addCarb, uploading, uploaded], timeout: 2, enforceOrder: true)
    }

    /// Adds two entries, validating their transition as the delegate calls completion out-of-order
    func testAddAndSyncInterleve() {
        let entry1 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let entry2 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let addCarb1 = expectation(description: "Add carb entry")
        let addCarb2 = expectation(description: "Add carb entry")
        let uploading1 = expectation(description: "Sync delegate: upload")
        let uploading2 = expectation(description: "Sync delegate: upload")
        let uploaded = expectation(description: "Sync delegate: completed")
        uploaded.expectedFulfillmentCount = 2

        // 2. assert sync delegate called
        uploadHandler = { (entries, completion) in
            XCTAssertEqual(1, entries.count)

            // 3. assert entered in db as uploading
            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                XCTAssertEqual(self.uploadMessages.count, objects.count)
                for object in objects {
                    XCTAssertEqual(.uploading, object.uploadState)
                }
            }

            switch self.uploadMessages.count {
            case 1:
                uploading1.fulfill()
                self.carbStore.addCarbEntry(entry2) { (result) in
                    addCarb2.fulfill()
                }
            case 2:
                uploading2.fulfill()

                for index in (0...1).reversed() {
                    var entry = self.uploadMessages[index].entries.first!
                    entry.externalID = "\(index)"
                    entry.isUploaded = true
                    self.uploadMessages[index].completion([entry])

                    // 4. call delegate completion
                    self.cacheStore.managedObjectContext.performAndWait {
                        let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                        for object in objects {
                            if object.externalID == "\(index)" {
                                XCTAssertEqual(.uploaded, object.uploadState)
                            }
                        }
                        uploaded.fulfill()
                    }
                }
            default:
                XCTFail()
            }
        }

        // 1. Add carb 1
        carbStore.addCarbEntry(entry1) { (result) in
            addCarb1.fulfill()
        }

        wait(for: [addCarb1, uploading1, addCarb2, uploading2, uploaded], timeout: 2, enforceOrder: true)
    }

    /// Adds an entry with a failed upload, validates its requested again for sync on next entry
    func testAddAndSyncMultipleCallbacks() {
        let entry1 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let entry2 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let addCarb1 = expectation(description: "Add carb entry")
        let addCarb2 = expectation(description: "Add carb entry")
        let uploading1 = expectation(description: "Sync delegate: upload")
        let uploading2 = expectation(description: "Sync delegate: upload")
        let uploaded = expectation(description: "Sync delegate: completed")
        uploaded.expectedFulfillmentCount = 2

        // 2. assert sync delegate called
        uploadHandler = { (entries, completion) in
            // 3. assert entered in db as uploading
            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                XCTAssertEqual(self.uploadMessages.count, objects.count)
                for object in objects {
                    XCTAssertEqual(.uploading, object.uploadState)
                }
            }

            switch self.uploadMessages.count {
            case 1:
                XCTAssertEqual(1, entries.count)
                uploading1.fulfill()
                completion(entries)  // Not uploaded

                self.carbStore.addCarbEntry(entry2) { (result) in
                    addCarb2.fulfill()
                }
            case 2:
                XCTAssertEqual(2, entries.count)
                uploading2.fulfill()

                for index in (0...1).reversed() {
                    var entry = self.uploadMessages[index].entries.first!
                    entry.externalID = "\(index)"
                    entry.isUploaded = true
                    self.uploadMessages[index].completion([entry])

                    // 4. call delegate completion
                    self.cacheStore.managedObjectContext.performAndWait {
                        let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                        for object in objects {
                            if object.externalID == "\(index)" {
                                XCTAssertEqual(.uploaded, object.uploadState)
                            }
                        }
                        uploaded.fulfill()
                    }
                }
            default:
                XCTFail()
            }
        }

        // 1. Add carb 1
        carbStore.addCarbEntry(entry1) { (result) in
            addCarb1.fulfill()
        }

        wait(for: [addCarb1, uploading1, addCarb2, uploading2, uploaded], timeout: 4, enforceOrder: true)
    }

    /// Adds and uploads an entry, then modifies it and validates its re-upload
    func testModifyUploadedCarb() {
        let entry1 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let entry2 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let sample2 = HKQuantitySample(type: carbStore.sampleType as! HKQuantityType, quantity: entry2.quantity, start: entry2.startDate, end: entry2.endDate)
        let addCarb1 = expectation(description: "Add carb entry")
        let addCarb2 = expectation(description: "Add carb entry")
        let uploading1 = expectation(description: "Sync delegate: upload")
        let uploading2 = expectation(description: "Sync delegate: upload")
        let uploaded = expectation(description: "Sync delegate: completed")

        var lastUUID: UUID?

        // 2. assert sync delegate called
        uploadHandler = { (entries, completion) in
            // 3. assert entered in db as uploading
            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                XCTAssertEqual(1, objects.count)
                XCTAssertEqual(.uploading, objects[0].uploadState)
                if let lastUUID = lastUUID {
                    XCTAssertNotEqual(lastUUID, objects[0].uuid)
                }
                lastUUID = objects[0].uuid
            }

            switch self.uploadMessages.count {
            case 1:
                XCTAssertEqual(1, entries.count)
                uploading1.fulfill()

                var entry = entries.first!
                entry.externalID = "1234"
                entry.isUploaded = true
                completion([entry])

                self.healthStore.queryResults = (samples: [sample2], error: nil)
                self.carbStore.replaceCarbEntry(entries.first!, withEntry: entry2) { (result) in
                    addCarb2.fulfill()

                    self.healthStore.queryResults = nil
                }
            case 2:
                XCTAssertEqual(1, entries.count)
                XCTAssertEqual("1234", entries.first!.externalID)
                XCTAssertFalse(entries.first!.isUploaded)
                uploading2.fulfill()

                var entry = entries.first!
                entry.isUploaded = true
                completion([entry])

                // 4. call delegate completion
                self.cacheStore.managedObjectContext.performAndWait {
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(1, objects.count)
                    for object in objects {
                        XCTAssertEqual(.uploaded, object.uploadState)
                    }
                    uploaded.fulfill()
                }
            default:
                XCTFail()
            }
        }

        deleteHandler = { (entries, completion) in
            XCTFail()
        }

        // 1. Add carb 1
        carbStore.addCarbEntry(entry1) { (result) in
            addCarb1.fulfill()
        }

        wait(for: [addCarb1, uploading1, addCarb2, uploading2, uploaded], timeout: 2, enforceOrder: true)
    }

    /// Adds an entry, modifying it before upload completes, validating the delegate is then asked to delete it
    func testModifyNotUploadedCarb() {
        let entry1 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 10), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let entry2 = NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 15), startDate: Date(), foodType: nil, absorptionTime: .hours(3))
        let sample2 = HKQuantitySample(type: carbStore.sampleType as! HKQuantityType, quantity: entry2.quantity, start: entry2.startDate, end: entry2.endDate)
        let addCarb1 = expectation(description: "Add carb entry")
        let addCarb2 = expectation(description: "Add carb entry")
        let uploading1 = expectation(description: "Sync delegate: upload")
        let uploading2 = expectation(description: "Sync delegate: upload")
        let uploaded = expectation(description: "Sync delegate: completed")
        let deleted = expectation(description: "Sync delegate: deleted")

        // 2. assert sync delegate called
        uploadHandler = { (entries, completion) in
            // 3. assert entered in db as uploading
            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                XCTAssertEqual(1, objects.count)
                for object in objects {
                    XCTAssertEqual(.uploading, object.uploadState)
                }
            }

            switch self.uploadMessages.count {
            case 1:
                XCTAssertEqual(1, entries.count)
                uploading1.fulfill()

                self.healthStore.queryResults = (samples: [sample2], error: nil)
                self.carbStore.replaceCarbEntry(entries.first!, withEntry: entry2) { (result) in
                    addCarb2.fulfill()

                    self.healthStore.queryResults = nil
                }
            case 2:
                XCTAssertEqual(1, entries.count)
                XCTAssertNil(entries.first!.externalID)
                XCTAssertFalse(entries.first!.isUploaded)
                uploading2.fulfill()

                var entry = entries.first!
                entry.externalID = "1234"
                entry.isUploaded = true
                completion([entry])

                entry = self.uploadMessages[0].entries.first!
                entry.externalID = "5678"
                entry.isUploaded = true
                self.uploadMessages[0].completion([entry])

                // 4. call delegate completion
                self.cacheStore.managedObjectContext.performAndWait {
                    let objects: [CachedCarbObject] = self.cacheStore.managedObjectContext.all()
                    XCTAssertEqual(1, objects.count)
                    for object in objects {
                        XCTAssertEqual("1234", object.externalID)
                        XCTAssertEqual(.uploaded, object.uploadState)
                    }

                    uploaded.fulfill()
                }
            default:
                XCTFail()
            }
        }

        deleteHandler = { (entries, completion) in
            XCTAssertEqual(1, entries.count)
            var entry = entries[0]
            XCTAssertEqual("5678", entry.externalID)
            XCTAssertFalse(entry.isUploaded)

            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [DeletedCarbObject] = self.cacheStore.managedObjectContext.all()
                XCTAssertEqual(1, objects.count)
                for object in objects {
                    XCTAssertEqual("5678", object.externalID)
                    XCTAssertEqual(.uploading, object.uploadState)
                }
            }

            entry.isUploaded = true
            completion([entry])

            self.cacheStore.managedObjectContext.performAndWait {
                let objects: [DeletedCarbObject] = self.cacheStore.managedObjectContext.all()
                XCTAssertEqual(0, objects.count)
            }

            deleted.fulfill()
        }

        // 1. Add carb 1
        carbStore.addCarbEntry(entry1) { (result) in
            addCarb1.fulfill()
        }

        wait(for: [addCarb1, uploading1, addCarb2, uploading2, uploaded, deleted], timeout: 2, enforceOrder: true)
    }
}
