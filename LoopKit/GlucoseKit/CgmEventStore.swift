//
//  CgmEventStore.swift
//  LoopKit
//
//  Created by Pete Schwamb on 9/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import CoreData
import HealthKit
import os.log

public protocol CgmEventStoreDelegate: AnyObject {

    /**
     Informs the delegate that the cgm event store has updated event data.

     - Parameter cgmEventStore: The cgm event store that has updated event data.
     */
    func cgmEventStoreHasUpdatedData(_ cgmEventStore: CgmEventStore)

}

/**
 Manages storage and retrieval of cgm events
 */
public final class CgmEventStore {

    public weak var delegate: CgmEventStoreDelegate?

    /// The interval of cgm event data to keep in cache
    public let cacheLength: TimeInterval

    private let log = OSLog(category: "CgmEventStore")

    private let cacheStore: PersistenceController

    private let queue = DispatchQueue(label: "com.loopkit.CgmEventStore.queue", qos: .utility)

    // MARK: - ReadyState
    private enum ReadyState {
        case waiting
        case ready
        case error(Error)
    }

    public typealias ReadyCallback = (_ error: Error?) -> Void

    private var readyCallbacks: [ReadyCallback] = []

    private var readyState: ReadyState = .waiting

    public func onReady(_ callback: @escaping ReadyCallback) {
        queue.async {
            switch self.readyState {
            case .waiting:
                self.readyCallbacks.append(callback)
            case .ready:
                callback(nil)
            case .error(let error):
                callback(error)
            }
        }
    }

    /// The maximum length of time to keep data around.
    public var cacheStartDate: Date {
        return Date().addingTimeInterval(-cacheLength)
    }

    public init(
        cacheStore: PersistenceController,
        cacheLength: TimeInterval = 60 /* minutes */ * 60 /* seconds */
    ) {
        self.cacheStore = cacheStore
        self.cacheLength = cacheLength

        cacheStore.onReady { (error) in
            guard error == nil else {
                self.queue.async {
                    self.readyState = .error(error!)
                    for callback in self.readyCallbacks {
                        callback(error)
                    }
                    self.readyCallbacks = []
                }
                return
            }

            cacheStore.fetchAnchor(key: GlucoseStore.healthKitQueryAnchorMetadataKey) { (anchor) in
                self.queue.async {
                    self.readyState = .ready
                    for callback in self.readyCallbacks {
                        callback(error)
                    }
                    self.readyCallbacks = []

                }
            }
        }
    }
}

// MARK: - Fetching

extension CgmEventStore {

    public struct QueryAnchor: Equatable, RawRepresentable {

        public typealias RawValue = [String: Any]

        internal var modificationCounter: Int64

        public init() {
            self.modificationCounter = 0
        }

        public init?(rawValue: RawValue) {
            guard let modificationCounter = rawValue["modificationCounter"] as? Int64 else {
                return nil
            }
            self.modificationCounter = modificationCounter
        }

        public var rawValue: RawValue {
            var rawValue: RawValue = [:]
            rawValue["modificationCounter"] = modificationCounter
            return rawValue
        }
    }

    /**
     Adds and persists a new cgm event

     - parameter unitVolume: The reservoir volume, in units
     - parameter date:       The date of the volume reading
     - parameter completion: A closure called after the value was saved. This closure takes three arguments:
        - value:                    The new reservoir value, if it was saved
        - previousValue:            The last new reservoir value
        - areStoredValuesContinous: Whether the current recent state of the stored reservoir data is considered continuous and reliable for deriving insulin effects after addition of this new value.
        - error:                    An error object explaining why the value could not be saved
     */
    public func add(events: [PersistedCgmEvent]) async throws {
        try await cacheStore.managedObjectContext.perform {

            for event in events {
                let cgmEvent = CgmEvent(context: self.cacheStore.managedObjectContext)
                cgmEvent.date = event.date
                cgmEvent.type = event.type
                cgmEvent.deviceIdentifier = event.deviceIdentifier
                cgmEvent.expectedLifetime = event.expectedLifetime
                cgmEvent.warmupPeriod = event.warmupPeriod
                cgmEvent.failureMessage = event.failureMessage
                cgmEvent.storedAt = Date()
            }

            if let error = self.cacheStore.save() {
                self.log.error("Error saving CGM event: %{public}@", error.localizedDescription)
                throw error
            }

            try self.purgeOldCgmEvents()

            self.delegate?.cgmEventStoreHasUpdatedData(self)
        }
    }


    public enum CgmEventQueryResult {
        case success(QueryAnchor, [PersistedCgmEvent])
        case failure(Error)
    }

    public func executeCgmEventQuery(fromQueryAnchor queryAnchor: QueryAnchor?, completion: @escaping (CgmEventQueryResult) -> Void) {
        var queryAnchor = queryAnchor ?? QueryAnchor()
        var queryResult = [PersistedCgmEvent]()
        var queryError: Error?

        cacheStore.managedObjectContext.performAndWait {
            let storedRequest: NSFetchRequest<CgmEvent> = CgmEvent.fetchRequest()

            storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
            storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]

            do {
                let stored = try self.cacheStore.managedObjectContext.fetch(storedRequest)
                if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                    queryAnchor.modificationCounter = modificationCounter
                }
                queryResult.append(contentsOf: stored.compactMap { $0.persistedCgmEvent })
            } catch let error {
                queryError = error
            }
        }

        if let queryError = queryError {
            completion(.failure(queryError))
            return
        }

        completion(.success(queryAnchor, queryResult))
    }

    private func purgeOldCgmEvents() throws {

        let predicate = NSPredicate(format: "storedAt < %@", cacheStartDate as NSDate)

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: CgmEvent.entity().name!)
        fetchRequest.predicate = predicate

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            if let result = try cacheStore.managedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult,
                let objectIDs = result.result as? [NSManagedObjectID],
                objectIDs.count > 0
            {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [cacheStore.managedObjectContext])
            }
        } catch let error as NSError {
            throw PersistenceController.PersistenceControllerError.coreDataError(error)
        }
    }

}

