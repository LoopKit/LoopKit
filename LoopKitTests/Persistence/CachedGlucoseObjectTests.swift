//
//  CachedGlucoseObjectTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class CachedGlucoseObjectTests: PersistenceControllerTestCase {

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

class CachedGlucoseObjectEncodableTests: PersistenceControllerTestCase {
    func testEncodable() throws {
        cacheStore.managedObjectContext.performAndWait {
            let cachedGlucoseObject = CachedGlucoseObject(context: cacheStore.managedObjectContext)
            cachedGlucoseObject.uuid = UUID(uuidString: "2A67A303-5203-4CB8-8263-79498265368E")!
            cachedGlucoseObject.syncIdentifier = "7723A0EE-F6D5-46E0-BBFE-1DEEBF8ED6F2"
            cachedGlucoseObject.syncVersion = 2
            cachedGlucoseObject.uploadState = .notUploaded
            cachedGlucoseObject.value = 98.7
            cachedGlucoseObject.unitString = "mg/dL"
            cachedGlucoseObject.startDate = dateFormatter.date(from: "2020-05-14T22:38:14Z")!
            cachedGlucoseObject.provenanceIdentifier = "238E41EA-9576-4981-A1A4-51E10228584F"
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
  "uploadState" : 0,
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
            cachedGlucoseObject.syncVersion = 1
            cachedGlucoseObject.value = 87.6
            cachedGlucoseObject.startDate = dateFormatter.date(from: "2020-05-14T22:38:14Z")!
            cachedGlucoseObject.isDisplayOnly = true
            cachedGlucoseObject.wasUserEntered = false
            cachedGlucoseObject.modificationCounter = 234
            try! assertCachedGlucoseObjectEncodable(cachedGlucoseObject, encodesJSON: """
{
  "isDisplayOnly" : true,
  "modificationCounter" : 234,
  "startDate" : "2020-05-14T22:38:14Z",
  "syncVersion" : 1,
  "uploadState" : 0,
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

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension CachedGlucoseObject {
    fileprivate func setDefaultValues() {
        provenanceIdentifier = "CachedGlucoseObjectTests"
        startDate = Date()
        uuid = UUID()
        syncIdentifier = uuid!.uuidString
        unitString = "mg/dL"
        value = 99
    }
}
