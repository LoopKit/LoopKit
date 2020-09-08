//
//  DeletedCarbObjectTests.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

class DeletedCarbObjectTests: PersistenceControllerTestCase {

    func testExternalIDUniqueConstraint() {
        cacheStore.managedObjectContext.performAndWait {
            let uuid = UUID()

            let object1 = DeletedCarbObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()
            object1.externalID = uuid.uuidString

            try! cacheStore.managedObjectContext.save()

            let object2 = DeletedCarbObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()
            object2.externalID = uuid.uuidString

            try! cacheStore.managedObjectContext.save()

            let objects: [DeletedCarbObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(1, objects.count)
        }
    }

    func testSaveWithDefaultValues() {
        cacheStore.managedObjectContext.performAndWait {
            let object1 = DeletedCarbObject(context: cacheStore.managedObjectContext)
            object1.setDefaultValues()

            try! cacheStore.managedObjectContext.save()

            let object2 = DeletedCarbObject(context: cacheStore.managedObjectContext)
            object2.setDefaultValues()

            try! cacheStore.managedObjectContext.save()

            let objects: [DeletedCarbObject] = cacheStore.managedObjectContext.all()
            XCTAssertEqual(2, objects.count)
        }
    }
}


extension DeletedCarbObject {
    fileprivate func setDefaultValues() {
        externalID = UUID().uuidString
        startDate = Date()
    }
}
