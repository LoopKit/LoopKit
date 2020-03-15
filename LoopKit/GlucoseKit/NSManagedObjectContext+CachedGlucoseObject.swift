//
//  NSManagedObjectContext+CachedGlucoseObject.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData


extension NSManagedObjectContext {
    
    internal func cachedGlucoseObjectsWithUUIDs(_ uuids: [UUID], fetchLimit: Int? = nil) -> [CachedGlucoseObject] {
        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
        if let limit = fetchLimit {
            request.fetchLimit = limit
        }
        request.predicate = NSPredicate(format: "uuid IN %@", uuids.map { $0 as NSUUID })
        request.sortDescriptors = [NSSortDescriptor(key: "uuid", ascending: true)]
        
        let results: [CachedGlucoseObject]
        do {
            results = try fetch(request)
        } catch {
            results = []
        }
        return results
    }
    
    internal func cachedGlucoseObjectsWithUUID(_ uuid: UUID, fetchLimit: Int? = nil) -> [CachedGlucoseObject] {
        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
        if let limit = fetchLimit {
            request.fetchLimit = limit
        }
        request.predicate = NSPredicate(format: "uuid == %@", uuid as NSUUID)
        request.sortDescriptors = [NSSortDescriptor(key: "uuid", ascending: true)]

        return (try? fetch(request)) ?? []
    }

    internal func cachedGlucoseObjectsWithSyncIdentifier(_ syncIdentifier: String, fetchLimit: Int? = nil) -> [CachedGlucoseObject] {
        let request: NSFetchRequest<CachedGlucoseObject> = CachedGlucoseObject.fetchRequest()
        if let limit = fetchLimit {
            request.fetchLimit = limit
        }
        request.predicate = NSPredicate(format: "syncIdentifier == %@", syncIdentifier)

        return (try? fetch(request)) ?? []
    }
}
