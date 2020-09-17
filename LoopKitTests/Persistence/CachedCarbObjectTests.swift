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


extension CachedCarbObject {
    fileprivate func setDefaultValues() {
        createdByCurrentApp = true
        startDate = Date()
    }
}
