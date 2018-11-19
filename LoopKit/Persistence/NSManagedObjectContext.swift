//
//  NSManagedObjectContext.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData


extension NSManagedObjectContext {

    /// Deletes all saved objects matching the specified type and predicate from the context's persistent store
    ///
    /// - Parameters:
    ///   - type: The object type to delete
    ///   - predicate: The predicate to match
    /// - Returns: The number of deleted objects
    /// - Throws: NSBatchDeleteRequest exeuction errors
    internal func purgeObjects<T: NSManagedObject>(of type: T.Type, matching predicate: NSPredicate) throws -> Int {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = T.fetchRequest()
        fetchRequest.predicate = predicate

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        let result = try execute(deleteRequest)
        guard let deleteResult = result as? NSBatchDeleteResult,
            let objectIDs = deleteResult.result as? [NSManagedObjectID]
        else {
            return 0
        }

        if objectIDs.count > 0 {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self])
            self.refreshAllObjects()
        }

        return objectIDs.count
    }
}
