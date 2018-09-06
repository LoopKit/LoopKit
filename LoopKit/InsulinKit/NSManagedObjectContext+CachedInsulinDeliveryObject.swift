//
//  NSManagedObjectContext+CachedInsulinDeliveryObject.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData


extension NSManagedObjectContext {
    internal func cachedInsulinDeliveryObjectsWithUUID(_ uuid: UUID, fetchLimit: Int? = nil) -> [CachedInsulinDeliveryObject] {
        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
        if let limit = fetchLimit {
            request.fetchLimit = limit
        }
        request.predicate = NSPredicate(format: "uuid == %@", uuid as NSUUID)
        request.sortDescriptors = [NSSortDescriptor(key: "uuid", ascending: true)]

        return (try? fetch(request)) ?? []
    }

    internal func cachedInsulinDeliveryObjectsWithSyncIdentifier(_ syncIdentifier: String, fetchLimit: Int? = nil) -> [CachedInsulinDeliveryObject] {
        let request: NSFetchRequest<CachedInsulinDeliveryObject> = CachedInsulinDeliveryObject.fetchRequest()
        if let limit = fetchLimit {
            request.fetchLimit = limit
        }
        request.predicate = NSPredicate(format: "syncIdentifier == %@", syncIdentifier)

        return (try? fetch(request)) ?? []
    }
}
