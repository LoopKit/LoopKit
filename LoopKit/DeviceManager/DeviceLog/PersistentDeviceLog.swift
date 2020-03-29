//
//  PersistentDeviceLog.swift
//  LoopKit
//
//  Created by Pete Schwamb on 1/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData
import os.log


// Using a framework specific class will search the framework's bundle for model files.
class PersistentContainer: NSPersistentContainer { }

public class PersistentDeviceLog {
    
    private let storageFile: URL
    
    private let managedObjectContext: NSManagedObjectContext

    private let persistentContainer: NSPersistentContainer
    
    private let maxEntryAge: TimeInterval
    
    private var earliestLogEntryDate: Date {
        return Date(timeIntervalSinceNow: -maxEntryAge)
    }
    
    private let log = OSLog(category: "PersistentDeviceLog")
    
    public init(storageFile: URL, maxEntryAge: TimeInterval = TimeInterval(7 * 24 * 60 * 60)) {
        self.storageFile = storageFile
        self.maxEntryAge = maxEntryAge

        managedObjectContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        managedObjectContext.automaticallyMergesChangesFromParent = true

        let storeDescription = NSPersistentStoreDescription(url: storageFile)
        persistentContainer = PersistentContainer(name: "DeviceLog")
        persistentContainer.persistentStoreDescriptions = [storeDescription]
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        managedObjectContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
    }
    
    public func log(managerIdentifier: String, deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)? = nil) {
        managedObjectContext.perform {
            let entry = DeviceLogEntry(context: self.managedObjectContext)
            entry.managerIdentifier = managerIdentifier
            entry.deviceIdentifier = deviceIdentifier
            entry.type = type
            entry.message = message
            entry.timestamp = Date()
            do {
                try self.managedObjectContext.save()
                self.log.default("Logged: %{public}@ (%{public}@) %{public}@", String(describing: type), deviceIdentifier ?? "", message)
                completion?(nil)
            } catch let error {
                self.log.error("Could not store device log entry %{public}@", String(describing: error))
                completion?(error)
            }
        }
    }
    
    public func getLogEntries(startDate: Date, endDate: Date? = nil, completion: @escaping (_ result: Result<[StoredDeviceLogEntry], Error>) -> Void) {
        
        managedObjectContext.perform {
            var predicate: NSPredicate = NSPredicate(format: "timestamp >= %@", startDate as NSDate)
            if let endDate = endDate {
                let endFilter = NSPredicate(format: "timestamp < %@", endDate as NSDate)
                predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, endFilter])
            }
            
            let request: NSFetchRequest<DeviceLogEntry> = DeviceLogEntry.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]
            
            do {
                let entries = try self.managedObjectContext.fetch(request)
                completion(.success(entries.map { StoredDeviceLogEntry(managedObject: $0) } ))
                self.purgeExpiredLogEntries()
            } catch let error {
                completion(.failure(error))
            }
        }
    }
    
    // Should only be called from managed object context queue
    private func purgeExpiredLogEntries() {
        let predicate = NSPredicate(format: "timestamp < %@", earliestLogEntryDate as NSDate)

        do {
            let fetchRequest: NSFetchRequest<DeviceLogEntry> = DeviceLogEntry.fetchRequest()
            fetchRequest.predicate = predicate
            let count = try managedObjectContext.deleteObjects(matching: fetchRequest)
            log.info("Deleted %d DeviceLogEntries", count)
        } catch let error {
            log.error("Could not purge expired log entry %{public}@", String(describing: error))
        }
    }
}

extension NSManagedObjectContext {

    fileprivate func deleteObjects<T>(matching fetchRequest: NSFetchRequest<T>) throws -> Int where T: NSManagedObject {
        let objects = try fetch(fetchRequest)

        for object in objects {
            delete(object)
        }

        if hasChanges {
            try save()
        }

        return objects.count
    }
}
