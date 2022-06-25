//
//  CachedGlucoseObjectTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class CachedGlucoseObjectTests: PersistenceControllerTestCase {
    func testSyncVersionGet() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.primitiveSyncVersion = NSNumber(integerLiteral: 3)
            XCTAssertEqual(object.syncVersion, 3)
        }
    }

    func testSyncVersionGetNil() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.primitiveSyncVersion = nil
            XCTAssertNil(object.syncVersion)
        }
    }

    func testSyncVersionSet() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.syncVersion = 5
            XCTAssertEqual(object.primitiveSyncVersion, NSNumber(integerLiteral: 5))
        }
    }

    func testSyncVersionSetNil() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.syncVersion = nil
            XCTAssertNil(object.primitiveSyncVersion)
        }
    }
}

class CachedGlucoseObjectModificationTests: PersistenceControllerTestCase {
    func testHasUpdatedModificationCounter() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.setDefaultValues()
            XCTAssertTrue(object.hasUpdatedModificationCounter)
            try! cacheStore.managedObjectContext.save()
            XCTAssertFalse(object.hasUpdatedModificationCounter)
        }
    }

    func testUpdateModificationCounter() {
        cacheStore.managedObjectContext.performAndWait {
            let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object.modificationCounter = -1
            object.updateModificationCounter()
            XCTAssertNotEqual(object.modificationCounter, -1)
        }
    }

    func testAwakeFromInsertUpdatesModificationCounter() {
        func testHasUpdatedModificationCounter() {
            cacheStore.managedObjectContext.performAndWait {
                let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
                XCTAssertTrue(object.hasUpdatedModificationCounter)
            }
        }
    }

    func testWillSaveUpdatesModificationCounter() {
        func testHasUpdatedModificationCounter() {
            cacheStore.managedObjectContext.performAndWait {
                let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
                XCTAssertTrue(object.hasUpdatedModificationCounter)
                object.setDefaultValues()
                object.modificationCounter = -1
                try! cacheStore.managedObjectContext.save()
                XCTAssertEqual(object.modificationCounter, -1)
                object.uuid = UUID()
                try! cacheStore.managedObjectContext.save()
                XCTAssertNotEqual(object.modificationCounter, -1)
            }
        }
    }

    func testWillSaveDoesNotUpdateModificationCounterIfManuallyUpdated() {
        func testHasUpdatedModificationCounter() {
            cacheStore.managedObjectContext.performAndWait {
                let object = CachedGlucoseObject(context: cacheStore.managedObjectContext)
                XCTAssertTrue(object.hasUpdatedModificationCounter)
                object.setDefaultValues()
                object.modificationCounter = -1
                try! cacheStore.managedObjectContext.save()
                XCTAssertEqual(object.modificationCounter, -1)
                object.uuid = UUID()
                object.modificationCounter = -2
                try! cacheStore.managedObjectContext.save()
                XCTAssertEqual(object.modificationCounter, -2)
            }
        }
    }
}

class CachedGlucoseObjectConstraintTests: PersistenceControllerTestCase {
    func testUUIDUniqueConstraint() {
        cacheStore.managedObjectContext.performAndWait {
            let uuid = UUID()

            let object1 = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()
            object1.uuid = uuid

            try! cacheStore.managedObjectContext.save()

            let object2 = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()
            object2.uuid = uuid

            try! cacheStore.managedObjectContext.save()

            let objects: [CachedGlucoseObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(1, objects.count)
        }
    }

    func testSyncIdentifierUniqueConstraint() {
        cacheStore.managedObjectContext.performAndWait {
            let uuid = UUID()

            let object1 = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()
            object1.syncIdentifier = uuid.uuidString

            try! cacheStore.managedObjectContext.save()

            let object2 = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()
            object2.syncIdentifier = uuid.uuidString

            try! cacheStore.managedObjectContext.save()

            let objects: [CachedGlucoseObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(1, objects.count)
        }
    }

    func testAllUniqueConstraints() {
        cacheStore.managedObjectContext.performAndWait {
            let uuid = UUID()

            let object1 = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()
            object1.uuid = uuid
            object1.syncIdentifier = uuid.uuidString

            try! cacheStore.managedObjectContext.save()

            let object2 = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()
            object2.uuid = uuid
            object2.syncIdentifier = uuid.uuidString

            try! cacheStore.managedObjectContext.save()

            let objects: [CachedGlucoseObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(1, objects.count)
        }
    }

    func testSaveWithDefaultValues() {
        cacheStore.managedObjectContext.performAndWait {
            let object1 = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()

            try! cacheStore.managedObjectContext.save()

            let object2 = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()

            try! cacheStore.managedObjectContext.save()

            let objects: [CachedGlucoseObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(2, objects.count)
        }
    }
}

class CachedGlucoseObjectQuantityTests: PersistenceControllerTestCase {
    func testQuantity() throws {
        cacheStore.managedObjectContext.performAndWait {
            let cachedGlucoseObject = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            cachedGlucoseObject.value = 123.45
            cachedGlucoseObject.unitString = HKUnit.milligramsPerDeciliter.unitString
            XCTAssertEqual(cachedGlucoseObject.quantity, HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 123.45))
        }
    }
}

class CachedGlucoseObjectEncodableTests: PersistenceControllerTestCase {
    func testEncodable() throws {
        cacheStore.managedObjectContext.performAndWait {
            let cachedGlucoseObject = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            cachedGlucoseObject.uuid = UUID(uuidString: "2A67A303-5203-4CB8-8263-79498265368E")!
            cachedGlucoseObject.provenanceIdentifier = "238E41EA-9576-4981-A1A4-51E10228584F"
            cachedGlucoseObject.syncIdentifier = "7723A0EE-F6D5-46E0-BBFE-1DEEBF8ED6F2"
            cachedGlucoseObject.syncVersion = 2
            cachedGlucoseObject.value = 98.7
            cachedGlucoseObject.unitString = HKUnit.milligramsPerDeciliter.unitString
            cachedGlucoseObject.startDate = dateFormatter.date(from: "2020-05-14T22:38:14Z")!
            cachedGlucoseObject.isDisplayOnly = false
            cachedGlucoseObject.wasUserEntered = true
            cachedGlucoseObject.modificationCounter = 123
            try! assertCachedGlucoseObjectEncodable(cachedGlucoseObject, encodesJSON: """
{
  "isDisplayOnly" : false,
  "modificationCounter" : 123,
  "provenanceIdentifier" : "238E41EA-9576-4981-A1A4-51E10228584F",
  "startDate" : "2020-05-14T22:38:14Z",
  "syncIdentifier" : "7723A0EE-F6D5-46E0-BBFE-1DEEBF8ED6F2",
  "syncVersion" : 2,
  "unitString" : "mg/dL",
  "uuid" : "2A67A303-5203-4CB8-8263-79498265368E",
  "value" : 98.700000000000003,
  "wasUserEntered" : true
}
"""
            )
        }
    }

    func testEncodableOptional() throws {
        cacheStore.managedObjectContext.performAndWait {
            let cachedGlucoseObject = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            cachedGlucoseObject.provenanceIdentifier = "238E41EA-9576-4981-A1A4-51E10228584F"
            cachedGlucoseObject.value = 87.6
            cachedGlucoseObject.unitString = HKUnit.milligramsPerDeciliter.unitString
            cachedGlucoseObject.startDate = dateFormatter.date(from: "2020-05-14T22:38:14Z")!
            cachedGlucoseObject.isDisplayOnly = true
            cachedGlucoseObject.wasUserEntered = false
            cachedGlucoseObject.modificationCounter = 234
            try! assertCachedGlucoseObjectEncodable(cachedGlucoseObject, encodesJSON: """
{
  "isDisplayOnly" : true,
  "modificationCounter" : 234,
  "provenanceIdentifier" : "238E41EA-9576-4981-A1A4-51E10228584F",
  "startDate" : "2020-05-14T22:38:14Z",
  "unitString" : "mg/dL",
  "value" : 87.599999999999994,
  "wasUserEntered" : false
}
"""
            )
        }
    }

    private func assertCachedGlucoseObjectEncodable(_ original: CachedGlucoseObject, encodesJSON string: String) throws {
        let data = try encoder.encode(original)
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
    }

    private let dateFormatter = ISO8601DateFormatter()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension CachedGlucoseObject {
    fileprivate func setDefaultValues() {
        self.uuid = UUID()
        self.provenanceIdentifier = "CachedGlucoseObjectTests"
        self.syncIdentifier = UUID().uuidString
        self.syncVersion = 2
        self.value = 99.9
        self.unitString = HKUnit.milligramsPerDeciliter.unitString
        self.startDate = Date()
        self.isDisplayOnly = false
        self.wasUserEntered = false
        self.condition = nil
        self.trend = .up
        self.trendRate = HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: 1.0)
    }
}
