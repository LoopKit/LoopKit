//
//  PersistenceControllerTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
import CoreData
import HealthKit
@testable import LoopKit

class PersistenceControllerTests: PersistenceControllerTestCase {

    func testPurgeObjectsBeforeSave() {
        cacheStore.managedObjectContext.performAndWait {
            for value in stride(from: 95, to: 105, by: 1) {
                let glucose = CachedGlucoseObject(context: cacheStore.managedObjectContext)
                glucose.uuid = UUID()
                glucose.provenanceIdentifier = "PersistenceControllerTests"
                glucose.syncIdentifier = "foo\(value)"
                glucose.syncVersion = 1
                glucose.value = Double(value)
                glucose.unitString = HKUnit.milligramsPerDeciliter.unitString
                glucose.startDate = Date()
                glucose.isDisplayOnly = false
                glucose.wasUserEntered = false
            }

            let predicate = NSPredicate(format: "value < %d", 100)
            let count = try! cacheStore.managedObjectContext.purgeObjects(of: CachedGlucoseObject.self, matching: predicate)

            XCTAssertEqual(0, count)

            try! cacheStore.managedObjectContext.save()

            let all: [CachedGlucoseObject] = cacheStore.managedObjectContext.all()

            XCTAssertEqual(10, all.count)
        }
    }

    func testPurgeObjectsAfterSave() {
        cacheStore.managedObjectContext.performAndWait {
            for value in stride(from: 95, to: 105, by: 1) {
                let glucose = CachedGlucoseObject(context: cacheStore.managedObjectContext)
                glucose.uuid = UUID()
                glucose.provenanceIdentifier = "PersistenceControllerTests"
                glucose.syncIdentifier = "foo\(value)"
                glucose.syncVersion = 1
                glucose.value = Double(value)
                glucose.unitString = HKUnit.milligramsPerDeciliter.unitString
                glucose.startDate = Date()
                glucose.isDisplayOnly = false
                glucose.wasUserEntered = false
            }

            try! cacheStore.managedObjectContext.save()

            let predicate = NSPredicate(format: "value < %d", 100)
            let count = try! cacheStore.managedObjectContext.purgeObjects(of: CachedGlucoseObject.self, matching: predicate)

            XCTAssertEqual(5, count)

            let all: [CachedGlucoseObject] = cacheStore.managedObjectContext.all()

            XCTAssertEqual(5, all.count)
        }
    }
    
}
