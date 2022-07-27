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
    
    public var earliestLogEntryDate: Date {
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
        // Grab timestamp at time of log, in case managedObjectContext is busy
        let timestamp = Date()

        managedObjectContext.perform {
            let entry = DeviceLogEntry(context: self.managedObjectContext)
            entry.managerIdentifier = managerIdentifier
            entry.deviceIdentifier = deviceIdentifier
            entry.type = type
            entry.message = message
            entry.timestamp = timestamp
            do {
                try self.managedObjectContext.save()
                if type == .error {
                    self.log.error("%{public}@ (%{public}@) %{public}@", String(describing: type), deviceIdentifier ?? "", message)
                } else {
                    self.log.default("%{public}@ (%{public}@) %{public}@", String(describing: type), deviceIdentifier ?? "", message)
                }
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

    public func purgeLogEntries(before date: Date, completion: ((Error?) -> Void)? = nil) {
        var purgeError: Error?

        managedObjectContext.performAndWait {
            do {
                let count = try managedObjectContext.purgeObjects(of: DeviceLogEntry.self, matching: NSPredicate(format: "timestamp < %@", date as NSDate))
                log.info("Purged %d DeviceLogEntries", count)
            } catch let error {
                log.error("Unable to purge DeviceLogEntries: %{public}@", String(describing: error))
                purgeError = error
            }
        }

        completion?(purgeError)
    }
}

// MARK: - Critical Event Log Export

extension PersistentDeviceLog: CriticalEventLog {
    private var exportProgressUnitCountPerObject: Int64 { 1 }
    private var exportFetchLimit: Int { Int(criticalEventLogExportProgressUnitCountPerFetch / exportProgressUnitCountPerObject) }

    public var exportName: String { "DeviceLog.json" }

    public func exportProgressTotalUnitCount(startDate: Date, endDate: Date? = nil) -> Result<Int64, Error> {
        var result: Result<Int64, Error>?

        self.managedObjectContext.performAndWait {
            do {
                let request: NSFetchRequest<DeviceLogEntry> = DeviceLogEntry.fetchRequest()
                request.predicate = self.exportDatePredicate(startDate: startDate, endDate: endDate)

                let objectCount = try self.managedObjectContext.count(for: request)
                result = .success(Int64(objectCount) * exportProgressUnitCountPerObject)
            } catch let error {
                result = .failure(error)
            }
        }

        return result!
    }

    public func export(startDate: Date, endDate: Date, to stream: OutputStream, progress: Progress) -> Error? {
        let encoder = JSONStreamEncoder(stream: stream)
        var modificationCounter: Int64 = 0
        var fetching = true
        var error: Error?

        while fetching && error == nil {
            self.managedObjectContext.performAndWait {
                do {
                    guard !progress.isCancelled else {
                        throw CriticalEventLogError.cancelled
                    }

                    let request: NSFetchRequest<DeviceLogEntry> = DeviceLogEntry.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "modificationCounter > %d", modificationCounter),
                                                                                            self.exportDatePredicate(startDate: startDate, endDate: endDate)])
                    request.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                    request.fetchLimit = self.exportFetchLimit

                    let objects = try self.managedObjectContext.fetch(request)
                    if objects.isEmpty {
                        fetching = false
                        return
                    }

                    try encoder.encode(objects)

                    modificationCounter = objects.last!.modificationCounter

                    progress.completedUnitCount += Int64(objects.count) * exportProgressUnitCountPerObject
                } catch let fetchError {
                    error = fetchError
                }
            }
        }

        if let closeError = encoder.close(), error == nil {
            error = closeError
        }

        return error
    }

    private func exportDatePredicate(startDate: Date, endDate: Date? = nil) -> NSPredicate {
        var predicate = NSPredicate(format: "timestamp >= %@", startDate as NSDate)
        if let endDate = endDate {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, NSPredicate(format: "timestamp < %@", endDate as NSDate)])
        }
        return predicate
    }
}

// MARK: - Core Data (Bulk) - TEST ONLY

extension PersistentDeviceLog {
    public func addStoredDeviceLogEntries(entries: [StoredDeviceLogEntry]) -> Error? {
        guard !entries.isEmpty else {
            return nil
        }

        var error: Error?

        self.managedObjectContext.performAndWait {
            for entry in entries {
                let object = DeviceLogEntry(context: self.managedObjectContext)
                object.update(from: entry)
            }
            do {
                try self.managedObjectContext.save()
            } catch let saveError {
                error = saveError
            }
        }

        guard error == nil else {
            return error
        }

        self.log.info("Added %d StoredDeviceLogEntries", entries.count)
        return nil
    }
}
