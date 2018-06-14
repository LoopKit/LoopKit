//
//  CacheStore.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData
@testable import LoopKit


extension PersistenceController {
    func tearDown() {
        managedObjectContext.performAndWait {
            let coordinator = self.managedObjectContext.persistentStoreCoordinator!
            let store = coordinator.persistentStores.first!
            let url = coordinator.url(for: store)
            try! self.managedObjectContext.persistentStoreCoordinator!.destroyPersistentStore(at: url, ofType: NSSQLiteStoreType, options: nil)
        }
    }
}
