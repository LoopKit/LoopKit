//
//  CachedCarbObjectTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class CachedCarbObjectTests: PersistenceControllerTestCase {
    func testSaveWithDefaultValues() {
        cacheStore.managedObjectContext.performAndWait {
            let object1 = CachedCarbObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()

            try! cacheStore.managedObjectContext.save()

            let object2 = CachedCarbObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()

            try! cacheStore.managedObjectContext.save()

            let objects: [CachedCarbObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(2, objects.count)
        }
    }
}

class CachedCarbObjectEncodableTests: PersistenceControllerTestCase {
    func testEncodable() throws {
        cacheStore.managedObjectContext.performAndWait {
            let cachedCarbObject = CachedCarbObject(context: cacheStore.managedObjectContext)
            cachedCarbObject.absorptionTime = 18000
            cachedCarbObject.createdByCurrentApp = true
            cachedCarbObject.foodType = "Pizza"
            cachedCarbObject.grams = 45
            cachedCarbObject.startDate = dateFormatter.date(from: "2020-05-14T22:38:14Z")!
            cachedCarbObject.uuid = UUID(uuidString: "2A67A303-5203-4CB8-8263-79498265368E")!
            cachedCarbObject.provenanceIdentifier = "238E41EA-9576-4981-A1A4-51E10228584F"
            cachedCarbObject.syncIdentifier = "7723A0EE-F6D5-46E0-BBFE-1DEEBF8ED6F2"
            cachedCarbObject.syncVersion = 2
            cachedCarbObject.userCreatedDate = dateFormatter.date(from: "2020-05-14T22:28:12Z")!
            cachedCarbObject.userUpdatedDate = dateFormatter.date(from: "2020-05-14T22:33:47Z")!
            cachedCarbObject.userDeletedDate = nil
            cachedCarbObject.operation = .update
            cachedCarbObject.addedDate = dateFormatter.date(from: "2020-05-14T22:33:48Z")!
            cachedCarbObject.supercededDate = nil
            cachedCarbObject.anchorKey = 123
            try! assertCachedCarbObjectEncodable(cachedCarbObject, encodesJSON: """
{
  "absorptionTime" : 18000,
  "addedDate" : "2020-05-14T22:33:48Z",
  "anchorKey" : 123,
  "createdByCurrentApp" : true,
  "foodType" : "Pizza",
  "grams" : 45,
  "operation" : 1,
  "provenanceIdentifier" : "238E41EA-9576-4981-A1A4-51E10228584F",
  "startDate" : "2020-05-14T22:38:14Z",
  "syncIdentifier" : "7723A0EE-F6D5-46E0-BBFE-1DEEBF8ED6F2",
  "syncVersion" : 2,
  "userCreatedDate" : "2020-05-14T22:28:12Z",
  "userUpdatedDate" : "2020-05-14T22:33:47Z",
  "uuid" : "2A67A303-5203-4CB8-8263-79498265368E"
}
"""
            )
        }
    }

    func testEncodableOptional() throws {
        cacheStore.managedObjectContext.performAndWait {
            let cachedCarbObject = CachedCarbObject(context: cacheStore.managedObjectContext)
            cachedCarbObject.createdByCurrentApp = false
            cachedCarbObject.grams = 34
            cachedCarbObject.startDate = dateFormatter.date(from: "2020-05-15T22:38:14Z")!
            cachedCarbObject.provenanceIdentifier = "238E41EA-9576-4981-A1A4-51E10228584F"
            cachedCarbObject.operation = .create
            cachedCarbObject.anchorKey = 234
            try! assertCachedCarbObjectEncodable(cachedCarbObject, encodesJSON: """
{
  "anchorKey" : 234,
  "createdByCurrentApp" : false,
  "grams" : 34,
  "operation" : 0,
  "provenanceIdentifier" : "238E41EA-9576-4981-A1A4-51E10228584F",
  "startDate" : "2020-05-15T22:38:14Z"
}
"""
            )
        }
    }

    private func assertCachedCarbObjectEncodable(_ original: CachedCarbObject, encodesJSON string: String) throws {
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

extension CachedCarbObject {
    fileprivate func setDefaultValues() {
        self.absorptionTime = .hours(3)
        self.createdByCurrentApp = true
        self.foodType = "Breakfast"
        self.grams = 45.6
        self.startDate = Date()
        self.uuid = UUID()
        self.provenanceIdentifier = "CachedCarbObjectTests"
        self.syncIdentifier = UUID().uuidString
        self.syncVersion = 1
        self.userCreatedDate = Date()
        self.userUpdatedDate = nil
        self.userDeletedDate = nil
        self.operation = .create
        self.addedDate = Date()
        self.supercededDate = nil
    }
}
