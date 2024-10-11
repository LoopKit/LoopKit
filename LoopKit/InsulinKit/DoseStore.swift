//
//  DoseStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/27/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import CoreData
import HealthKit
import os.log
import LoopAlgorithm

public protocol DoseStoreDelegate: AnyObject {

    /**
     Informs the delegate that the dose store has updated pump event data.

     - Parameter doseStore: The dose store that has updated pump event data.
     */
    func doseStoreHasUpdatedPumpEventData(_ doseStore: DoseStore)

    /**
     Provides a history timeline of scheduled basal rates.
     */
    func scheduledBasalHistory(from start: Date, to end: Date) async throws -> [AbsoluteScheduleValue<Double>]

}

public enum DoseStoreResult<T> {
    case success(T)
    case failure(DoseStore.DoseStoreError)
}

/**
 Manages storage, retrieval, and calculation of insulin pump delivery data.
 
 Pump data are stored in the following tiers:
 
 * In-memory cache, used for IOB and insulin effect calculation
 ```
 0            [1.5 * insulinActionDuration]
 |––––––––––––––––––––—————————––|
 ```
 * On-disk Core Data store, unprotected
 ```
 0                           [24 hours]
 |––––––––––––––––––––––—————————|
 ```
 * HealthKit data, managed by the current application and persisted indefinitely
 ```
 0
 |––––––––––––––––––––––——————————————>
 ```

 Private members should be assumed to not be thread-safe, and access should be contained to within blocks submitted to `persistenceStore.managedObjectContext`, which executes them on a private, serial queue.
 */
public final class DoseStore {
    
    /// Notification posted when data was modifed.
    public static let valuesDidChange = NSNotification.Name(rawValue: "com.loopkit.DoseStore.valuesDidChange")

    public enum DoseStoreError: Error {
        case configurationError
        case initializationError(description: String, recoverySuggestion: String?)
        case persistenceError(description: String, recoverySuggestion: String?)
        case fetchError(description: String, recoverySuggestion: String?)

        init?(error: PersistenceController.PersistenceControllerError?) {
            if let error = error {
                self = .persistenceError(description: String(describing: error), recoverySuggestion: error.recoverySuggestion)
            } else {
                return nil
            }
        }
    }

    public weak var delegate: DoseStoreDelegate?

    private let log = OSLog(category: "DoseStore")
    
    public var longestEffectDuration: TimeInterval

    public let insulinDeliveryStore: InsulinDeliveryStore

    /// The representation of the insulin pump for Health storage
    public var device: HKDevice? {
        get {
            return lockedDevice.value
        }
        set {
            lockedDevice.value = newValue
        }
    }
    private let lockedDevice = Locked<HKDevice?>(nil)

    /// Whether the pump generates events indicating the start of a scheduled basal rate after it had been interrupted.
    public var pumpRecordsBasalProfileStartEvents: Bool = false

    /// The sync version used for new samples written to HealthKit
    /// Choose a lower or higher sync version if the same sample might be written twice (e.g. from an extension and from an app) for deterministic conflict resolution
    public let syncVersion: Int

    public var hkSampleStore: HealthKitSampleStore? {
        return insulinDeliveryStore.hkSampleStore
    }

    /// Window for retrieving historical doses that might be used to reconcile current events
    private let pumpEventReconciliationWindow = TimeInterval(hours: 24)

    
    // MARK: -

    /// Initializes and configures a new store
    ///
    /// - Parameters:
    ///   - healthKitSampleStore: The HealthKit store for reading & writing insulin delivery
    ///   - cacheStore: The cache store for reading & writing short-term intermediate data
    ///   - cacheLength: Maximum age of data to keep in the store.
    ///   - longestEffectDuration: This determines the oldest age of doses to be retrieved for calculating glucose effects
    ///   - syncVersion: A version number for determining resolution in de-duplication
    ///   - lastPumpEventsReconciliation: The date the PumpManger last reconciled with the pump
    ///   - provenanceIdentifier: An id to store with new doses, indicating the provenance of the dose, usually the app's bundle identifier.
    ///   - onReady: A closure that will be called after initialization.
    ///   - test_currentDate: Used for testing to mock current time
    public init(
        healthKitSampleStore: HealthKitSampleStore? = nil,
        cacheStore: PersistenceController,
        cacheLength: TimeInterval = 24 /* hours */ * 60 /* minutes */ * 60 /* seconds */,
        longestEffectDuration: TimeInterval = InsulinMath.longestInsulinActivityDuration,
        syncVersion: Int = 1,
        lastPumpEventsReconciliation: Date? = nil,
        provenanceIdentifier: String = HKSource.default().bundleIdentifier,
        onReady: ((DoseStoreError?) -> Void)? = nil,
        test_currentDate: Date? = nil
    ) async {
        self.insulinDeliveryStore = await InsulinDeliveryStore(
            healthKitSampleStore: healthKitSampleStore,
            cacheStore: cacheStore,
            cacheLength: cacheLength,
            provenanceIdentifier: provenanceIdentifier,
            test_currentDate: test_currentDate
        )
        self.longestEffectDuration = longestEffectDuration
        self.persistenceController = cacheStore
        self.cacheLength = cacheLength
        self.syncVersion = syncVersion
        self.lockedLastPumpEventsReconciliation = Locked(lastPumpEventsReconciliation)

        self.pumpEventQueryAfterDate = cacheStartDate

        persistenceController.onReady { (error) -> Void in
            guard error == nil else {
                onReady?(.init(error: error))
                return
            }

            self.persistenceController.managedObjectContext.perform {
                // Find the newest PumpEvent date we have
                let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                request.predicate = NSPredicate(format: "mutable != true")
                request.fetchLimit = 1

                if let events = try? self.persistenceController.managedObjectContext.fetch(request), let lastEvent = events.first {
                    self.pumpEventQueryAfterDate = lastEvent.date
                }

                // Validate the state of the stored reservoir data.
                self.validateReservoirContinuity()

                onReady?(nil)
            }
        }
    }

    /// Clears all pump data from the on-disk store.
    ///
    /// Calling this method may result in data loss, as there is no check to ensure data has been synced first.
    ///
    /// - Parameter completion: A closure to call after the reset has completed
    public func resetPumpData() async throws {
        log.info("Resetting all cached pump data")
        do {
            try await deleteAllPumpEvents()
        } catch {
            log.error("Error deleting all pump events: %{public}@", String(describing: error))
        }
        try await self.deleteAllReservoirValues()
    }

    private let persistenceController: PersistenceController

    private let cacheLength: TimeInterval

    private var purgeableValuesPredicate: NSPredicate {
        return NSPredicate(format: "date < %@", cacheStartDate as NSDate)
    }

    /// The maximum length of time to keep data around.
    /// Dose data is unprotected on disk, and should only remain persisted long enough to support dosing algorithms and until its persisted by the delegate.
    public var cacheStartDate: Date {
        return currentDate(timeIntervalSinceNow: -cacheLength)
    }

    private var recentStartDate: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: currentDate())!
    }

    internal func currentDate(timeIntervalSinceNow: TimeInterval = 0) -> Date {
        return insulinDeliveryStore.currentDate(timeIntervalSinceNow: timeIntervalSinceNow)
    }

    // MARK: - Reservoir Data

    /// The last-created reservoir object.
    private var lastStoredReservoirValue: StoredReservoirValue? {
        get {
            return lockedLastStoredReservoirValue.value
        }
        set {
            lockedLastStoredReservoirValue.value = newValue
        }
    }
    private let lockedLastStoredReservoirValue = Locked<StoredReservoirValue?>(nil)

    // The last-saved reservoir value
    public var lastReservoirValue: ReservoirValue? {
        return lastStoredReservoirValue
    }

    /// An incremental cache of temp basal doses based on reservoir records, used to avoid repeated work.
    ///
    /// *Access should be isolated to a managed object context block*
    private var recentReservoirNormalizedDoseEntriesCache: [DoseEntry]?

    /**
     *This method should only be called from within a managed object context block.*
     */
    private func clearReservoirNormalizedDoseCache() {
        recentReservoirNormalizedDoseEntriesCache = nil
    }

    /// Whether the current recent state of the stored reservoir data is considered
    /// continuous and reliable for the derivation of insulin effects
    ///
    /// *Access should be isolated to a managed object context block*
    private var areReservoirValuesValid = false


    // MARK: - Pump Event Data

    /// The earliest event date that should included in subsequent queries for pump event data.
    public private(set) var pumpEventQueryAfterDate: Date {
        get {
            return lockedPumpEventQueryAfterDate.value
        }
        set {
            lockedPumpEventQueryAfterDate.value = newValue
        }
    }
    private let lockedPumpEventQueryAfterDate = Locked<Date>(.distantPast)

    /// The last time the PumpManager reconciled events with the pump.
    public private(set) var lastPumpEventsReconciliation: Date? {
        get {
            return lockedLastPumpEventsReconciliation.value
        }
        set {
            lockedLastPumpEventsReconciliation.value = newValue
        }
    }
    private let lockedLastPumpEventsReconciliation: Locked<Date?>

    public var lastAddedPumpData: Date {
        return [lastReservoirValue?.startDate, lastPumpEventsReconciliation].compactMap { $0 }.max() ?? .distantPast
    }

    /// The date of the most recent pump prime event, if known.
    ///
    /// *Access should be isolated to a managed object context block*
    private var lastRecordedPrimeEventDate: Date? {
        get {
            if _lastRecordedPrimeEventDate == nil {
                if  let pumpEvents = try? self.getPumpEventObjects(
                        matching: NSPredicate(format: "type = %@", PumpEventType.prime.rawValue),
                        chronological: false,
                        limit: 1
                    ),
                    let firstEvent = pumpEvents.first
                {
                    _lastRecordedPrimeEventDate = firstEvent.date
                } else {
                    _lastRecordedPrimeEventDate = .distantPast
                }
            }

            return _lastRecordedPrimeEventDate
        }
        set {
            _lastRecordedPrimeEventDate = newValue
        }
    }
    private var _lastRecordedPrimeEventDate: Date?

}


// MARK: - Reservoir Operations
extension DoseStore {
    /// Validates the current reservoir data for reliability in glucose effect calculation at the specified date
    ///
    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameter date: The date to base the continuity calculation on. Defaults to now.
    /// - Returns: The array of reservoir data used in the calculation
    @discardableResult
    private func validateReservoirContinuity(at date: Date? = nil) -> [Reservoir] {
        let date = date ?? currentDate()

        // Consider any entries longer than 30 minutes, or with a value of 0, to be unreliable
        let maximumInterval = TimeInterval(minutes: 30)
        
        let continuityStartDate = date.addingTimeInterval(-longestEffectDuration)

        if  let recentReservoirObjects = try? self.getReservoirObjects(since: continuityStartDate - maximumInterval),
            let oldestRelevantReservoirObject = recentReservoirObjects.last
        {
            // Verify reservoir timestamps are continuous
            let areReservoirValuesContinuous = recentReservoirObjects.reversed().isContinuous(
                from: continuityStartDate,
                to: date,
                within: maximumInterval
            )
            
            // also make sure prime events don't exist withing the insulin action duration
            let primeEventExistsWithinInsulinActionDuration = (lastRecordedPrimeEventDate ?? .distantPast) >= oldestRelevantReservoirObject.startDate

            self.areReservoirValuesValid = areReservoirValuesContinuous && !primeEventExistsWithinInsulinActionDuration
            self.lastStoredReservoirValue = recentReservoirObjects.first?.storedReservoirValue

            return recentReservoirObjects
        }

        self.areReservoirValuesValid = false
        self.lastStoredReservoirValue = nil
        return []
    }

    /**
     Adds and persists a new reservoir value

     - parameter unitVolume: The reservoir volume, in units
     - parameter date:       The date of the volume reading
     - parameter completion: A closure called after the value was saved. This closure takes three arguments:
        - value:                    The new reservoir value, if it was saved
        - previousValue:            The last new reservoir value
        - areStoredValuesContinous: Whether the current recent state of the stored reservoir data is considered continuous and reliable for deriving insulin effects after addition of this new value.
        - error:                    An error object explaining why the value could not be saved
     */

    public func addReservoirValue(_ unitVolume: Double, at date: Date) async throws -> (value: ReservoirValue, previousValue: ReservoirValue?, areStoredValuesContinuous: Bool) {
        return try await self.persistenceController.managedObjectContext.perform {
            // Perform some sanity checking of the new value against the most recent value.
            if let previousValue = self.lastReservoirValue {
                let isOutOfOrder = previousValue.endDate > date
                let isSameDate = previousValue.endDate == date
                let isConflicting = isSameDate && previousValue.unitVolume != unitVolume
                if isOutOfOrder || isConflicting {
                    self.log.error("Added inconsistent reservoir value of %{public}.3fU at %{public}@ after %{public}.3fU at %{public}@. Resetting.", unitVolume, String(describing: date), previousValue.unitVolume, String(describing: previousValue.endDate))

                    // If we're violating consistency of the previous value, reset.
                    do {
                        try self.purgeReservoirObjects()
                        self.clearReservoirNormalizedDoseCache()
                        self.validateReservoirContinuity()
                    } catch let error {
                        self.log.error("Error purging reservoir objects: %{public}@", String(describing: error))
                        throw error
                    }
                    // If no error on purge, continue with creation
                } else if isSameDate && previousValue.unitVolume == unitVolume {
                    // Ignore duplicate adds
                    self.log.error("Ignoring duplicate reservoir value at %{public}@", String(describing: date))
                    return (previousValue, previousValue, self.areReservoirValuesValid)
                }
            }


            let reservoir = Reservoir(context: self.persistenceController.managedObjectContext)

            reservoir.volume = unitVolume
            reservoir.date = date

            let previousValue = self.lastStoredReservoirValue

            var newValues: [StoredReservoirValue] = []

            if let previousValue = previousValue {
                newValues.append(previousValue)
            }

            newValues.append(reservoir.storedReservoirValue)

            let newDoseEntries = newValues.doseEntries

            if self.recentReservoirNormalizedDoseEntriesCache != nil {
                self.recentReservoirNormalizedDoseEntriesCache = self.recentReservoirNormalizedDoseEntriesCache!.filterDateRange(self.recentStartDate, nil)
                self.recentReservoirNormalizedDoseEntriesCache! += newDoseEntries
            }

            // Remove reservoir objects older than our cache length
            try? self.purgeReservoirObjects(matching: self.purgeableValuesPredicate)
            // Trigger a re-evaluation of continuity and update self.lastStoredReservoirValue
            self.validateReservoirContinuity()

            let error = self.persistenceController.save()

            NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)

            if let error {
                throw error
            }

            return (
                reservoir.storedReservoirValue,
                previousValue,
                self.areReservoirValuesValid
            )
        }
    }

    /// Retrieves reservoir values since the given date.
    ///
    /// - Parameters:
    ///   - startDate: The earliest reservoir record date to include
    ///   - limit: An optional limit to the number of values returned
    ///   - completion: A closure called after retrieval
    ///   - result: An array of reservoir values in reverse-chronological order
    public func getReservoirValues(since startDate: Date, limit: Int? = nil, completion: @escaping (_ result: DoseStoreResult<[ReservoirValue]>) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                let values = try self.getReservoirObjects(since: startDate, limit: limit).map { $0.storedReservoirValue }

                completion(.success(values))
            } catch let error as DoseStoreError {
                completion(.failure(error))
            } catch {
                assertionFailure()
            }
        }
    }

    public func getReservoirValues(since startDate: Date, limit: Int? = nil) async throws -> [ReservoirValue] {
        try await withCheckedThrowingContinuation { continuation in
            getReservoirValues(since: startDate, limit: limit) { result in
                switch result {
                case .success(let values):
                    continuation.resume(returning: values)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }


    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameters:
    ///   - startDate: The earliest reservoir record date to include
    ///   - limit: An optional limit to the number of objects returned
    /// - Returns: An array of reservoir managed objects, in reverse-chronological order
    /// - Throws: An error describing the failure to fetch objects
    private func getReservoirObjects(since startDate: Date, limit: Int? = nil) throws -> [Reservoir] {
        let request: NSFetchRequest<Reservoir> = Reservoir.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            return try persistenceController.managedObjectContext.fetch(request)
        } catch let fetchError as NSError {
            throw DoseStoreError.fetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
        }
    }

    /// Retrieves normalized dose values derived from reservoir readings
    ///
    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameters:
    ///   - start: The earliest date of entries to include
    ///   - end: The latest date of entries to include, defaulting to the distant future.
    /// - Returns: An array of normalized entries
    /// - Throws: A DoseStoreError describing a failure
    private func getNormalizedReservoirDoseEntries(start: Date, end: Date? = nil) throws -> [DoseEntry] {
        if let normalizedDoses = self.recentReservoirNormalizedDoseEntriesCache, let firstDoseDate = normalizedDoses.first?.startDate, firstDoseDate <= start {
            return normalizedDoses.filterDateRange(start, end)
        } else {
            // Attempt to get the reading before "start", so we can build those doses that have an end date after "start", but a start date before "start"
            // Any extra doses will be filtered out below, via filterDateRange
            let doses = try self.getReservoirObjects(since: start.addingTimeInterval(-.minutes(10))).reversed().doseEntries

            self.recentReservoirNormalizedDoseEntriesCache = doses
            return doses.filterDateRange(start, end)
        }
    }

    /**
     Deletes a persisted reservoir value

     - parameter value:         The value to delete
     - parameter completion:    A closure called after the value was deleted. This closure takes two arguments:
     - parameter deletedValues: An array of removed values
     - parameter error:         An error object explaining why the value could not be deleted
     */
    public func deleteReservoirValue(_ value: ReservoirValue, completion: @escaping (_ deletedValues: [ReservoirValue], _ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform {
            var deletedObjects = [ReservoirValue]()
            if  let storedValue = value as? StoredReservoirValue,
                let objectID = self.persistenceController.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: storedValue.objectIDURL),
                let object = try? self.persistenceController.managedObjectContext.existingObject(with: objectID)
            {
                self.persistenceController.managedObjectContext.delete(object)
                deletedObjects.append(storedValue)
                self.validateReservoirContinuity()
            }

            let error = self.persistenceController.save()
            self.clearReservoirNormalizedDoseCache()
            completion(deletedObjects, DoseStoreError(error: error))
            NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
        }
    }

    /// Deletes all persisted reservoir values
    ///
    /// - Parameter completion: A closure called after all the values are deleted. This closure takes a single argument:
    /// - Parameter error: An error explaining why the deletion failed
    public func deleteAllReservoirValues() async throws {
        try await persistenceController.managedObjectContext.perform {
            self.log.info("Deleting all reservoir values")
            try self.purgeReservoirObjects()

            let error = self.persistenceController.save()
            self.clearReservoirNormalizedDoseCache()
            self.validateReservoirContinuity()
            NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
            if let error {
                throw error
            }
        }
    }

    /**
     Removes reservoir objects older than the recency predicate, and re-evaluates the continuity of the remaining objects

     *This method should only be called from within a managed object context block.*

     - throws: PersistenceController.PersistenceControllerError.coreDataError if the delete request failed
     */
    private func purgeReservoirObjects(matching predicate: NSPredicate? = nil) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Reservoir.entity().name!)
        fetchRequest.predicate = predicate

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        do {
            if let result = try persistenceController.managedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult,
                let objectIDs = result.result as? [NSManagedObjectID],
                objectIDs.count > 0
            {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [persistenceController.managedObjectContext])
                self.validateReservoirContinuity()
            }
        } catch let error as NSError {
            throw PersistenceController.PersistenceControllerError.coreDataError(error)
        }
    }
}


// MARK: - Pump Event Operations
extension DoseStore {
    /**
     Adds and persists new pump events.
     
     Events are deduplicated by a unique constraint on `NewPumpEvent.getter:raw`.

     - parameter events: An array of new pump events. Pump events should have end times reflective of when delivery is actually expected to be finished, as doses that end prior to a reservoir reading are ignored when reservoir data is being used.
     - parameter lastReconciliation: The date that pump events were most recently reconciled against recorded pump history. Pump events are assumed to be reflective of delivery up until this point in time. If reservoir values are recorded after this time, they may be used to supplement event based delivery.
     - parameter replacePendingEvents: If true, any existing pending events will be removed.
     - parameter completion: A closure called after the events are saved. The closure takes a single argument:
     - parameter error: An error object explaining why the events could not be saved.
     */
    public func addPumpEvents(_ events: [NewPumpEvent], lastReconciliation: Date?, replacePendingEvents: Bool = true) async throws {
        lastPumpEventsReconciliation = lastReconciliation

        guard events.count > 0 else {
            try await syncPumpEventsToInsulinDeliveryStore(resolveMutable: true)
            return
        }

        let now = self.currentDate()
        self.log.debug("addPumpEvents: lastReconciliation = %@ (%@ hours ago)", String(describing: lastReconciliation), String(describing: now.timeIntervalSince(lastReconciliation ?? now).hours))

        for event in events {
            if let dose = event.dose {
                self.log.debug("Add %@, isMutable=%@", String(describing: dose), String(describing: event.dose?.isMutable))
            }
        }

        try await self.persistenceController.managedObjectContext.perform {
            var lastFinalDate: Date?
            var firstMutableDate: Date?
            var primeValueAdded = false

            if replacePendingEvents {
                try self.purgePumpEventObjects(matching: NSPredicate(format: "mutable == YES"))
            }
            // Remove old doses
            do {
                try self.purgePumpEventObjectsInternal(before: self.cacheStartDate)
            } catch {
                self.log.error("Error purging PumpEvent objects: %{public}@", String(describing: error))
            }

            // There is no guarantee of event ordering, so we must search the entire array to find key date boundaries.

            for event in events {
                if case .prime? = event.type {
                    primeValueAdded = true
                }

                let isMutable = event.dose?.isMutable == true
                let wasProgrammedByPumpUI = event.dose?.wasProgrammedByPumpUI ?? false
                if isMutable {
                    firstMutableDate = min(event.date, firstMutableDate ?? event.date)
                } else {
                    lastFinalDate = max(event.date, lastFinalDate ?? event.date)
                }

                let object = PumpEvent(context: self.persistenceController.managedObjectContext)

                object.date = event.date
                object.raw = event.raw
                object.title = event.title
                object.type = event.type
                object.mutable = isMutable
                object.dose = event.dose
                object.alarmType = event.alarmType
                object.wasProgrammedByPumpUI = wasProgrammedByPumpUI
            }

            // Only change pumpEventQueryAfterDate if we received new finalized records.
            if let finalDate = lastFinalDate {
                if let mutableDate = firstMutableDate, mutableDate < finalDate {
                    self.pumpEventQueryAfterDate = mutableDate
                } else {
                    self.pumpEventQueryAfterDate = finalDate
                }
            }

            if primeValueAdded {
                self.lastRecordedPrimeEventDate = nil
                self.validateReservoirContinuity()
            }

            if let error = self.persistenceController.save() {
                self.log.error("Error adding new pump events: %{public}@", String(describing: error))
                throw error
            }
        }
        try await syncPumpEventsToInsulinDeliveryStore(resolveMutable: true)
        self.delegate?.doseStoreHasUpdatedPumpEventData(self)
        NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
    }


    public func deletePumpEvent(_ event: PersistedPumpEvent, completion: @escaping (_ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform {

            if  let objectID = self.persistenceController.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: event.objectIDURL),
                let object = try? self.persistenceController.managedObjectContext.existingObject(with: objectID)
            {
                self.persistenceController.managedObjectContext.delete(object)
            }

            // Reset the latest query date to the newest PumpEvent
            let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.predicate = NSPredicate(format: "mutable != true")
            request.fetchLimit = 1

            if let events = try? self.persistenceController.managedObjectContext.fetch(request),
                let lastEvent = events.first
            {
                self.pumpEventQueryAfterDate = lastEvent.date
            } else {
                self.pumpEventQueryAfterDate = self.cacheStartDate
            }

            let error = self.persistenceController.save()
            completion(DoseStoreError(error: error))
            NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
            self.lastRecordedPrimeEventDate = nil
            self.validateReservoirContinuity()
        }
    }

    /// Deletes all persisted pump events
    ///
    public func deleteAllPumpEvents() async throws {
        do {
            try await syncPumpEventsToInsulinDeliveryStore()
        } catch {
            self.log.error("Error performing final sync to insulin delivery store before deleteAllPumpEvents: %{public}@", String(describing: error))
        }

        try await self.persistenceController.managedObjectContext.perform {
            self.log.info("Deleting all pump events")
            try self.purgePumpEventObjects()

            let error = self.persistenceController.save()
            self.pumpEventQueryAfterDate = self.cacheStartDate
            self.lastPumpEventsReconciliation = nil
            self.lastRecordedPrimeEventDate = nil

            NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
            if let error {
                throw error
            }
        }
    }


    /**
     Adds and persists doses. Doses *cannot* be mutable.
     - parameter doses: An array of dose entries to add.
     - parameter completion: A closure called after the doses are saved. The closure takes a single argument:
     - parameter error: An error object explaining why the doses could not be saved.
     */
    public func addDoses(_ doses: [DoseEntry], from device: HKDevice?) async throws {
        assert(!doses.contains(where: { $0.isMutable }))
        guard doses.count > 0 else {
            return
        }

        if let error = self.persistenceController.save() {
            self.log.error("Error saving: %{public}@", String(describing: error))
        }

        try await insulinDeliveryStore.addDoseEntries(doses, from: device, syncVersion: self.syncVersion)
        try? await syncPumpEventsToInsulinDeliveryStore()
        NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
    }

    /**
     Synchronizes entries from a remote authoritative store.  Any existing doses with matching syncIdentifier will be replaced.
     - parameter entries: An array of dose entries to add.
     */
    public func syncDoseEntries(_ entries: [DoseEntry], updateExistingRecords: Bool = true) async throws {
        try await self.insulinDeliveryStore.syncDoseEntries(entries, updateExistingRecords: updateExistingRecords)
    }

    /// Deletes one particular manually entered dose from the store
    ///
    /// - Parameter dose: Dose to delete.
    /// - Parameter completion: A closure called after the event deleted. This closure takes a single argument:
    /// - Parameter success: True if dose was successfully deleted
    public func deleteDose(_ dose: DoseEntry, completion: @escaping (_ error: DoseStoreError?) -> Void) {
        guard let syncIdentifier = dose.syncIdentifier else {
            self.log.error("Unable to delete PersistedManualEntryDose: no syncIdentifier")
            completion(DoseStoreError.fetchError(description: "Unable to delete dose: syncIdentifier is missing", recoverySuggestion: "File an issue report in Github"))
            return
        }
        insulinDeliveryStore.deleteDose(bySyncIdentifier: syncIdentifier) { (error) in
            if let error = error {
                completion(DoseStoreError.persistenceError(description: error, recoverySuggestion: nil))
            } else {
                completion(nil)
                NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
            }
        }
    }

    /// Deletes all manually entered doses
    ///
    /// - Parameter completion: A closure called after all the events are deleted. This closure takes a single argument:
    /// - Parameter error: An error explaining why the deletion failed
    public func deleteAllManuallyEnteredDoses(since startDate: Date) async throws {
        self.log.info("Deleting all manually entered doses since %{public}@", String(describing: startDate))
        try await insulinDeliveryStore.deleteAllManuallyEnteredDoses(since: startDate)
        NotificationCenter.default.post(name: DoseStore.valuesDidChange, object: self)
    }

    /// Attempts to store doses from pump events to insulin delivery store
    public func syncPumpEventsToInsulinDeliveryStore(after start: Date? = nil, resolveMutable: Bool = false) async throws {
        var start = await insulinDeliveryStore.getLastImmutableBasalEndDate()

        if start == nil {
            let events = try await self.persistenceController.managedObjectContext.perform {
                try self.getPumpEventObjects(chronological: true, limit: 1)
            }
            if let firstPumpEvent = events.first {
                start = firstPumpEvent.startDate
            } else {
                // No previous basal, and no pump events; nothing to store or infer
                return
            }
        }
        // Limit the query behavior to 24 hours
        start = max(start!, self.recentStartDate)
        try await self.savePumpEventsToInsulinDeliveryStore(after: start!, resolveMutable: resolveMutable)
    }

    /// Processes and saves dose events on or after the given date to insulin delivery store
    ///
    /// - Parameters:
    ///   - start: The date on and after which to include doses
    ///   - resolveMutable: Resolve mutable dose entries during saving
    ///   - completion: A closure called on completion
    ///   - error: An error if one ocurred during processing or saving
    private func savePumpEventsToInsulinDeliveryStore(after start: Date, resolveMutable: Bool) async throws {
        let doses = try await getPumpEventDoseEntriesForSavingToInsulinDeliveryStore(startingAt: start)
        guard doses.count > 0 else {
            return
        }

        for dose in doses {
            self.log.debug("Adding dose to insulin delivery store: %@", String(describing: dose))
        }

        try await insulinDeliveryStore.addDoseEntries(doses, from: self.device, syncVersion: self.syncVersion, resolveMutable: resolveMutable)
    }

    /// Fetches a timeline of doses, filling in gaps between delivery changes with the scheduled basal delivery
    /// if the pump doesn't already handle this
    ///
    /// - Parameters:
    ///   - start: The date on and after which to include doses
    ///   - completion: A closure called on completion
    ///   - result: The doses along with schedule basal
    private func getPumpEventDoseEntriesForSavingToInsulinDeliveryStore(startingAt: Date) async throws -> [DoseEntry] {
        // Can't store to insulin delivery store if we don't know end of reconciled range, or if we already have doses after the end
        guard let endingAt = lastPumpEventsReconciliation, endingAt > startingAt else {
            self.log.error("lastPumpEventsReconciliation of %@ < startingAt %@. (lastImmutableBasalEndDate after lastPumpEventsReconciliation???", String(describing: lastPumpEventsReconciliation), String(describing: startingAt))
            return []
        }

        let doses = try await self.persistenceController.managedObjectContext.perform {
            try self.getNormalizedPumpEventDoseEntriesForSavingToInsulinDeliveryStore(basalStart: startingAt, end: self.currentDate())
        }

        guard let delegate = self.delegate else {
            throw DoseStoreError.configurationError
        }
        let basalHistory = try await delegate.scheduledBasalHistory(from: startingAt, to: endingAt)

        self.log.debug("Overlaying basal schedule for %d doses starting at %@", doses.count, String(describing: startingAt))
        return doses.overlayBasal(basalHistory, endDate: endingAt, lastPumpEventsReconciliation: endingAt)
    }

    /// Fetches manually entered doses.
    ///
    /// - Parameter startDate: The earliest dose startDate to include
    /// - Returns: An array of manually entered dose managed objects, in reverse-chronological order, or an error describing the failure to fetch objects
    public func getManuallyEnteredDoses(since startDate: Date) async throws -> [DoseEntry] {
        try await insulinDeliveryStore.getManuallyEnteredDoses(since: startDate, chronological: false)
    }

    /// Retrieves pump event values since the given date.
    ///
    /// - Parameters:
    ///   - startDate: The earliest pump event date to include
    ///   - completion: A closure called after retrieval
    ///   - result: An array of pump event values in reverse-chronological order
    public func getPumpEventValues(since startDate: Date, completion: @escaping (_ result: DoseStoreResult<[PersistedPumpEvent]>) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                let events = try self.getPumpEventObjects(since: startDate).map { $0.persistedPumpEvent }

                completion(.success(events))
            } catch let error as DoseStoreError {
                completion(.failure(error))
            } catch {
                assertionFailure()
            }
        }
    }

    public func getPumpEventValues(since startDate: Date) async throws -> [PersistedPumpEvent] {
        try await withCheckedThrowingContinuation { continuation in
            getPumpEventValues(since: startDate) { result in
                switch result {
                case .success(let events):
                    continuation.resume(returning: events)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameter startDate: The earliest pump event date to include
    /// - Returns: An array of pump event managed objects, in reverse-chronological order
    /// - Throws: An error describing the failure to fetch objects
    private func getPumpEventObjects(since startDate: Date) throws -> [PumpEvent] {
        return try getPumpEventObjects(
            matching: NSPredicate(format: "date >= %@", startDate as NSDate),
            chronological: false
        )
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// Objects are ordered by date using the DoseType sort ordering as a tiebreaker for stability
    ///
    /// - Parameters:
    ///   - predicate: The predicate to apply to the objects
    ///   - chronological: Whether to return the objects in chronological (true) or reverse-chronological (false) order
    /// - Returns: An array of pump events in the specified order by date
    /// - Throws: An error describing the failure to fetch objects
    private func getPumpEventObjects(matching predicate: NSPredicate? = nil, chronological: Bool = true, limit: Int? = nil) throws -> [PumpEvent] {
        let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: chronological)]

        if let limit = limit {
            request.fetchLimit = limit
        }

        do {
            return try persistenceController.managedObjectContext.fetch(request).sorted(by: { (lhs, rhs) -> Bool in
                let (first, second) = chronological ? (lhs, rhs) : (rhs, lhs)

                if  first.startDate == second.startDate,
                    let firstType = first.type, let secondType = second.type
                {
                    return firstType.sortOrder < secondType.sortOrder
                } else {
                    return first.startDate < second.startDate
                }
            })
        } catch let fetchError as NSError {
            throw DoseStoreError.fetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
        }
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameters:
    ///   - start: The earliest dose end date to include
    ///   - end: The latest dose start date to include
    /// - Returns: An array of doses from pump events
    /// - Throws: An error describing the failure to fetch objects
    private func getNormalizedPumpEventDoseEntries(start: Date, end: Date? = nil) throws -> [DoseEntry] {
        let queryStart = start.addingTimeInterval(-pumpEventReconciliationWindow)

        let doses = try getPumpEventObjects(
            matching: NSPredicate(format: "date >= %@ && doseType != nil", queryStart as NSDate),
            chronological: true
        ).compactMap({ $0.dose })
        let normalizedDoses = doses.reconciled()

        return normalizedDoses.filterDateRange(start, end)
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Returns: An array of doses from pump events that were marked mutable
    /// - Throws: An error describing the failure to fetch objects
    private func getNormalizedMutablePumpEventDoseEntries(start: Date) throws -> [DoseEntry] {
        let doses = try getPumpEventObjects(
            matching: NSPredicate(format: "mutable == true && doseType != nil"),
            chronological: true
            ).compactMap({ $0.dose })
        let normalizedDoses = doses.filterDateRange(start, nil).reconciled()
        return normalizedDoses.map { $0.trimmed(from: start) }
    }


    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameters:
    ///   - basalStart: The earliest basal dose start date to include
    ///   - end: The latest dose end date to include
    /// - Returns: An array of doses from pump events
    /// - Throws: An error describing the failure to fetch objects
    private func getNormalizedPumpEventDoseEntriesForSavingToInsulinDeliveryStore(basalStart: Date, end: Date) throws -> [DoseEntry] {
        self.log.info("Fetching Pump events between %{public}@ and %{public}@ for saving to InsulinDeliveryStore", String(describing: basalStart), String(describing: end))

        // Make sure we look far back enough to have prior temp basal records to reconcile
        // resumption of temp basal after suspend/resume.
        let queryStart = basalStart.addingTimeInterval(-pumpEventReconciliationWindow)

        let afterBasalStart = NSPredicate(format: "date >= %@ && doseType != nil", queryStart as NSDate)
        let allBoluses = NSPredicate(format: "date >= %@ && doseType == %@", recentStartDate as NSDate, DoseType.bolus.rawValue)

        let doses = try getPumpEventObjects(
            matching: NSCompoundPredicate(orPredicateWithSubpredicates: [afterBasalStart, allBoluses]),
            chronological: true
        ).compactMap({ $0.dose })
        // Ignore any doses which have not yet ended by the specified date.
        // Also, since we are retrieving dosing history older than basalStart for
        // reconciliation purposes, we need to filter that out after reconciliation.
        let normalizedDoses = doses.reconciled().filter({ $0.endDate <= end || $0.isMutable }).filter({ $0.startDate >= basalStart || $0.type == .bolus })

        return normalizedDoses
    }

    public func purgePumpEventObjects(before date: Date) async throws {
        try await persistenceController.managedObjectContext.perform {
            try self.purgePumpEventObjectsInternal(before: date)
        }
    }

    private func purgePumpEventObjectsInternal(before date: Date) throws {
        do {
            let count = try self.purgePumpEventObjects(matching: NSPredicate(format: "date < %@", date as NSDate))
            self.log.info("Purged %d PumpEvents", count)
        } catch let error {
            self.log.error("Unable to purge PumpEvents: %{public}@", String(describing: error))
            throw error
        }
    }

    /**
     Removes uploaded pump event objects older than the recency predicate

     *This method should only be called from within a managed object context block.*

     - throws: A core data exception if the delete request failed
     */
    @discardableResult
    private func purgePumpEventObjects(matching predicate: NSPredicate? = nil) throws -> Int {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: PumpEvent.entity().name!)
        fetchRequest.predicate = predicate

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        if  let result = try persistenceController.managedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult,
            let objectIDs = result.result as? [NSManagedObjectID],
            objectIDs.count > 0
        {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [persistenceController.managedObjectContext])
            persistenceController.managedObjectContext.refreshAllObjects()
            return objectIDs.count
        }

        return 0
    }
}


extension DoseStore {

    /// Retrieves dose entries normalized to the current basal schedule, for visualization purposes.
    ///
    /// Doses are derived from pump events if they've been updated within the last 15 minutes or reservoir data is incomplete.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - start: The earliest endDate of entries to retrieve
    ///   - end: The latest startDate of entries to retrieve, if provided
    ///   - completion: A closure called once the entries have been retrieved
    ///   - result: An array of dose entries, in chronological order by startDate
    public func getNormalizedDoseEntries(start: Date, end: Date? = nil) async throws -> [DoseEntry] {

        let insulinDeliveryDoses = try await insulinDeliveryStore.getDoseEntries(start: start, end: end, includeMutable: true)
        let filteredStart = max(self.lastPumpEventsReconciliation ?? start, start)

        return try await self.persistenceController.managedObjectContext.perform {
            do {
                var doses: [DoseEntry]

                // Reservoir data is used only if it's continuous and the pumpmanager hasn't reconciled since the last reservoir reading
                if self.areReservoirValuesValid, let reservoirEndDate = self.lastStoredReservoirValue?.startDate, reservoirEndDate > self.lastPumpEventsReconciliation ?? .distantPast {
                    let reservoirDoses = try self.getNormalizedReservoirDoseEntries(start: filteredStart, end: end)
                    let endOfReservoirData = self.lastStoredReservoirValue?.endDate ?? .distantPast
                    let startOfReservoirData = reservoirDoses.first?.startDate ?? filteredStart
                    let mutableDoses = try self.getNormalizedMutablePumpEventDoseEntries(start: endOfReservoirData)
                    doses = insulinDeliveryDoses.map({ $0.trimmed(to: startOfReservoirData) }) + reservoirDoses + mutableDoses.map({ $0.trimmed(from: endOfReservoirData) })
                } else {
                    // Deduplicates doses by syncIdentifier
                    doses = insulinDeliveryDoses.appendedUnion(with: try self.getNormalizedPumpEventDoseEntries(start: filteredStart, end: end))
                }

                // Extend an unfinished suspend out to end time
                return doses.map { dose in
                    var dose = dose
                    if dose.type == .suspend && dose.startDate == dose.endDate {
                        dose.endDate = end ?? self.currentDate()
                    }
                    return dose
                }
            }
        }
    }

    /// Retrieves most recent bolus
    ///
    /// - Parameters:
    ///   - returns: A DoseEntry representing the most recent bolus, or nil, if there is no recent bolus
    public func getLatestBolus() async throws -> DoseEntry? {
        return try await insulinDeliveryStore.getBoluses().first
    }

    /// Retrieves boluses
    ///
    /// - Parameters:
    ///   - start:If non-nil, select boluses that ended after start.
    ///   - end: If non-nil, select boluses that started before end.
    ///   - limit: If non-nill, specify the max number of boluses to return.
    ///   - returns: A list of DoseEntry objects representing the boluses that match the query parameters
    public func getBoluses(start: Date? = nil, end: Date? = nil) async throws -> [DoseEntry] {
        return try await insulinDeliveryStore.getBoluses(start: start, end: end)
    }

}

extension DoseStore {
    /// Generates a diagnostic report about the current state
    public func generateDiagnosticReport() async -> String {
        var report: [String] = [
            "## DoseStore",
            "",
            "* areReservoirValuesValid: \(areReservoirValuesValid)",
            "* lastPumpEventsReconciliation: \(String(describing: lastPumpEventsReconciliation))",
            "* lastStoredReservoirValue: \(String(describing: lastStoredReservoirValue))",
            "* pumpEventQueryAfterDate: \(pumpEventQueryAfterDate)",
            "* lastRecordedPrimeEventDate: \(String(describing: lastRecordedPrimeEventDate))",
            "* pumpRecordsBasalProfileStartEvents: \(pumpRecordsBasalProfileStartEvents)",
            "* device: \(String(describing: device))",
        ]

        let historyStart = Date().addingTimeInterval(-.hours(24))

        do {
            report.append("")
            report.append("### getReservoirValues")
            report.append("")
            report.append("* Reservoir(startDate, unitVolume)")
            for value in try await getReservoirValues(since: historyStart) {
                report.append("* \(value.startDate), \(value.unitVolume)")
            }

            report.append("")
            report.append("### getPumpEventValues")
            let values = try await getPumpEventValues(since: historyStart)
            var firstPumpEventDate = self.cacheStartDate
            report.append("")
            if let firstEvent = values.last {
                firstPumpEventDate = firstEvent.date
            }

            for value in values {
                report.append("* \(value)")
            }
            report.append("")
            report.append("### getManuallyEnteredDoses")
            let entries = try await self.getManuallyEnteredDoses(since: firstPumpEventDate)
            report.append("")
            for entry in entries {
                report.append("* \(entry)")
            }

            report.append("")
            report.append(await insulinDeliveryStore.generateDiagnosticReport())
            report.append("")
        } catch {
            report.append("Error: \(error)")
        }
        return report.joined(separator: "\n")
    }
}

extension DoseStore {

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

    public enum PumpEventQueryResult {
        case success(QueryAnchor, [PersistedPumpEvent])
        case failure(Error)
    }
    
    public func executePumpEventQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int) async throws -> (QueryAnchor, [PersistedPumpEvent]) {
        var queryAnchor = queryAnchor ?? QueryAnchor()
        var queryResult = [PersistedPumpEvent]()

        guard limit > 0 else {
            return (queryAnchor, [])
        }

        try await persistenceController.managedObjectContext.perform {
            let storedRequest: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()

            storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
            storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
            storedRequest.fetchLimit = limit

            let stored = try self.persistenceController.managedObjectContext.fetch(storedRequest)
            if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                queryAnchor.modificationCounter = modificationCounter
            }
            queryResult.append(contentsOf: stored.compactMap { $0.persistedPumpEvent })
        }

        return (queryAnchor, queryResult)
    }
}

// MARK: - Critical Event Log Export

extension DoseStore: CriticalEventLog {
    private var exportProgressUnitCountPerObject: Int64 { 1 }
    private var exportFetchLimit: Int { Int(criticalEventLogExportProgressUnitCountPerFetch / exportProgressUnitCountPerObject) }

    public var exportName: String { "Doses.json" }

    public func exportProgressTotalUnitCount(startDate: Date, endDate: Date? = nil) -> Result<Int64, Error> {
        var result: Result<Int64, Error>?

        self.persistenceController.managedObjectContext.performAndWait {
            do {
                let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
                request.predicate = self.exportDatePredicate(startDate: startDate, endDate: endDate)

                let objectCount = try self.persistenceController.managedObjectContext.count(for: request)
                result = .success(Int64(objectCount) * exportProgressUnitCountPerObject)
            } catch let error {
                result = .failure(error)
            }
        }

        return result!
    }

    public func export(startDate: Date, endDate: Date, to stream: DataOutputStream, progress: Progress) -> Error? {
        let encoder = JSONStreamEncoder(stream: stream)
        var modificationCounter: Int64 = 0
        var fetching = true
        var error: Error?

        while fetching && error == nil {
            self.persistenceController.managedObjectContext.performAndWait {
                do {
                    guard !progress.isCancelled else {
                        throw CriticalEventLogError.cancelled
                    }

                    let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "modificationCounter > %d", modificationCounter),
                                                                                            self.exportDatePredicate(startDate: startDate, endDate: endDate)])
                    request.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                    request.fetchLimit = self.exportFetchLimit

                    let objects = try self.persistenceController.managedObjectContext.fetch(request)
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
        var predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        if let endDate = endDate {
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, NSPredicate(format: "date < %@", endDate as NSDate)])
        }
        return predicate
    }
}

// MARK: - Core Data (Bulk) - TEST ONLY

extension DoseStore {
    public func addPumpEvents(events: [PersistedPumpEvent]) async throws {
        guard !events.isEmpty, !events.contains(where: { $0.dose?.isMutable == true }) else {
            return
        }

        try await persistenceController.managedObjectContext.perform {
            for event in events {
                let object = PumpEvent(context: self.persistenceController.managedObjectContext)
                object.update(from: event)
            }
            if let saveError = self.persistenceController.saveInternal() {
                throw saveError
            }
        }
        try await syncPumpEventsToInsulinDeliveryStore(after: events.compactMap { $0.date }.min())

        self.log.info("Added %d PumpEvents", events.count)
        self.delegate?.doseStoreHasUpdatedPumpEventData(self)
    }
}
