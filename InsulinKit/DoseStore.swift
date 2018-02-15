//
//  DoseStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/27/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import CoreData
import HealthKit
import LoopKit
import os.log


public protocol DoseStoreDelegate: class {
    /**
     Asks the delegate to upload recently-added pump events not yet marked as uploaded.
     
     The completion handler must be called in all circumstances, with an array of object IDs that were successfully uploaded and can be purged when they are no longer recent.
     
     - parameter doseStore:  The store instance
     - parameter pumpEvents: The pump events
     - parameter completion: The closure to execute when the upload attempt has finished. If no events were uploaded, call the closure with an empty array.
     - parameter uploadedObjects: The array of object IDs that were successfully uploaded
     */
    func doseStore(_ doseStore: DoseStore, hasEventsNeedingUpload pumpEvents: [PersistedPumpEvent], completion: @escaping (_ uploadedObjects: [NSManagedObjectID]) -> Void)
}


public extension NSNotification.Name {
    /// Notification posted when the ready state was modified.
    public static let DoseStoreReadyStateDidChange = NSNotification.Name(rawValue: "com.loopkit.DoseStore.ReadyStateDidUpdateNotification")

    /// Notification posted when data was modifed.
    public static let DoseStoreValuesDidChange = NSNotification.Name(rawValue: "com.loopkit.DoseStore.ValuesDidChangeNotification")
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

    public enum ReadyState {
        case needsConfiguration
        case initializing
        case ready
        case failed(DoseStoreError)
    }

    public var readyState = ReadyState.needsConfiguration {
        didSet {
            NotificationCenter.default.post(name: .DoseStoreReadyStateDidChange, object: self)
        }
    }

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

    public weak var delegate: DoseStoreDelegate? {
        didSet {
            isUploadRequestPending = false
        }
    }

    private let log = OSLog(category: "DoseStore")

    /// TODO: Isolate to queue
    public var insulinModel: InsulinModel? {
        didSet {
            persistenceController.managedObjectContext.perform {
                self.pumpEventQueryAfterDate = max(self.pumpEventQueryAfterDate, self.recentValuesStartDate)

                self.validateReservoirContinuity()
            }

            if let effectDuration = insulinModel?.effectDuration {
                insulinDeliveryStore.observationStart = Date(timeIntervalSinceNow: -effectDuration)
            }
        }
    }

    /// TODO: Isolate to queue
    public var basalProfile: BasalRateSchedule? {
        didSet {
            persistenceController.managedObjectContext.perform {
                self.clearReservoirNormalizedDoseCache()
            }
        }
    }

    /// TODO: Isolate to queue
    public var insulinSensitivitySchedule: InsulinSensitivitySchedule?

    /// TODO: Isolate to queue
    public var insulinDeliveryStore: InsulinDeliveryStore

    /// The HealthKit sample type managed by this store
    public var sampleType: HKSampleType? {
        return insulinDeliveryStore.sampleType
    }

    /// True if the store requires authorization
    public var authorizationRequired: Bool {
        return insulinDeliveryStore.authorizationRequired
    }

    /// True if the user has explicitly denied access to any required share types
    public var sharingDenied: Bool {
        return insulinDeliveryStore.sharingDenied
    }

    /// *Access should be isolated to a managed object context block*
    private var device: HKDevice?

    /// The representation of the insulin pump for Health storage
    /// This setter applies the new value asynchronously and returns immediately.
    public func setDevice(_ device: HKDevice?) {
        persistenceController.managedObjectContext.perform {
            self.device = device
        }
    }

    /// *Access should be isolated to a managed object context block*
    private var pumpRecordsBasalProfileStartEvents: Bool = false

    /// Whether the pump generates events indicating the start of a scheduled basal rate after it had been interrupted.
    ///
    /// This setter applies the new value asynchronously and returns immediately.
    public func setPumpRecordsBasalProfileStartEvents(_ doesRecord: Bool) {
        persistenceController.managedObjectContext.perform {
            self.pumpRecordsBasalProfileStartEvents = doesRecord
        }
    }

    // MARK: -

    /// Initializes and configures a new store
    ///
    /// - Parameters:
    ///   - healthStore: The HealthKit store for reading & writing insulin delivery
    ///   - cacheStore: The cache store for reading & writing short-term intermediate data
    ///   - insulinModel: The model of insulin effect over time
    ///   - basalProfile: The daily schedule of basal insulin rates
    ///   - insulinSensitivitySchedule: The daily schedule of insulin sensitivity (ISF)
    public init(healthStore: HKHealthStore, cacheStore: PersistenceController, insulinModel: InsulinModel?, basalProfile: BasalRateSchedule?, insulinSensitivitySchedule: InsulinSensitivitySchedule?) {
        self.insulinDeliveryStore = InsulinDeliveryStore(healthStore: healthStore, effectDuration: insulinModel?.effectDuration ?? .hours(6))
        self.insulinModel = insulinModel
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
        self.basalProfile = basalProfile
        self.readyState = .initializing
        self.persistenceController = cacheStore

        self.pumpEventQueryAfterDate = recentValuesStartDate

        persistenceController.onReady { [unowned self] (error) -> Void in
            if let error = error {
                self.log.error("Failed to initialize persistenceController: %{public}@", error.errorDescription ?? error.localizedDescription)
                self.readyState = .failed(.initializationError(description: error.localizedDescription, recoverySuggestion: error.recoverySuggestion))
            } else {
                self.persistenceController.managedObjectContext.perform {
                    // Find the newest PumpEvent date we have
                    let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
                    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                    request.fetchLimit = 1

                    if let events = try? self.persistenceController.managedObjectContext.fetch(request), let lastEvent = events.first {
                        self.pumpEventQueryAfterDate = lastEvent.date
                    }
                    
                    // Validate the state of the stored reservoir data.
                    self.validateReservoirContinuity()

                    // Warm the state of insulin delivery samples
                    self.insulinDeliveryStore.getLastBasalEndDate { (_) in }

                    self.readyState = .ready
                }
            }
        }
    }

    /// Clears all pump data from the on-disk store.
    ///
    /// Calling this method may result in data loss, as there is no check to ensure data has been synced first.
    ///
    /// - Parameter completion: A closure to call after the reset has completed
    public func resetPumpData(completion: ((_ error: DoseStoreError?) -> Void)? = nil) {
        log.info("Resetting all cached pump data")
        deleteAllPumpEvents { (error) in
            if let error = error {
                completion?(error)
            } else {
                self.deleteAllReservoirValues { (error) in
                    completion?(error)
                }
            }
        }
    }

    private let persistenceController: PersistenceController

    private var purgeableValuesPredicate: NSPredicate {
        return NSPredicate(format: "date < %@", cacheStartDate as NSDate)
    }

    /// The maximum length of time to keep data around.
    /// Dose data is unprotected on disk, and should only remain persisted long enough to support dosing algorithms and until its persisted by the delegate.
    private var cacheStartDate: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    /// A incremental cache of total insulin delivery since the last date requested by a client, used to avoid repeated work
    ///
    /// *Access should be isolated to a managed object context block*
    private var totalDeliveryCache: InsulinValue?

    /// The earliest date we should require for querying pump events, using (1.5 × the insulin model's effect duration)
    ///
    /// *Access should be isolated to a managed object context block*
    private var recentValuesStartDate: Date {
        let duration = (insulinModel?.effectDuration ?? 4) * 3 / 2
        return Date(timeIntervalSinceNow: -duration)
    }


    // MARK: - Reservoir Data

    /// The last-created reservoir object.
    /// *This setter should only be called from within a managed object context block.*
    private var lastStoredReservoirValue: StoredReservoirValue?

    // The last-saved reservoir value
    /// TODO: Isolate to queue
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
    ///
    /// TODO: Isolate to a queue
    public private(set) var pumpEventQueryAfterDate: Date = .distantPast

    /// The last time `addPumpEvents` was called, used to estimate recency of data.
    ///
    /// TODO: Isolate to a queue
    public private(set) var lastAddedPumpEvents = Date.distantPast

    /// The date of the most recent pump prime event, if known.
    /// To to read and check for updates use getLastPrimeEventDate()
    ///
    /// *Access should be isolated to a managed object context block*
    private var _lastRecordedPrimeEventDate: Date?

    /// Flag the existing last prime event date as invalid
    ///
    /// *Access should be isolated to a managed object context block*
    private func invalidateLastPrimeEventDate() {
        _lastRecordedPrimeEventDate = nil
    }

    /// The last-seen mutable pump events, which aren't persisted but are used for dose calculation.
    ///
    /// *Access should be isolated to a managed object context block*
    private var mutablePumpEventDoses: [DoseEntry] = []

    /**
     Whether there's an outstanding upload request to the delegate.

     *Access should be isolated to a managed object context block*
     */
    private var isUploadRequestPending = false
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
    private func validateReservoirContinuity(at date: Date = Date()) -> [Reservoir] {
        if let insulinModel = insulinModel {
            // Consider any entries longer than 30 minutes, or with a value of 0, to be unreliable
            let maximumInterval = TimeInterval(minutes: 30)
            let continuityStartDate = date.addingTimeInterval(-insulinModel.effectDuration)

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
                let primeEventExistsWithinInsulinActionDuration = getLastPrimeEventDate() >= oldestRelevantReservoirObject.startDate

                self.areReservoirValuesValid = areReservoirValuesContinuous && !primeEventExistsWithinInsulinActionDuration
                self.lastStoredReservoirValue = recentReservoirObjects.first?.storedReservoirValue

                return recentReservoirObjects
            }
        }

        self.areReservoirValuesValid = false
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
    public func addReservoirValue(_ unitVolume: Double, at date: Date, completion: @escaping (_ value: ReservoirValue?, _ previousValue: ReservoirValue?, _ areStoredValuesContinuous: Bool, _ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform { [unowned self] in
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
                        self.totalDeliveryCache = nil
                        self.clearReservoirNormalizedDoseCache()
                        self.validateReservoirContinuity()
                    } catch let error {
                        self.log.error("Error purging reservoir objects: %{public}@", String(describing: error))
                        completion(nil, nil, false, DoseStoreError(error: error as? PersistenceController.PersistenceControllerError))
                        return
                    }
                    // If no error on purge, continue with creation
                } else if isSameDate && previousValue.unitVolume == unitVolume {
                    // Ignore duplicate adds
                    self.log.error("Added duplicate reservoir value at %{public}@", String(describing: date))
                    completion(nil, previousValue, self.areReservoirValuesValid, nil)
                    return
                }
            }

            let reservoir = Reservoir(entity: Reservoir.entity(), insertInto: self.persistenceController.managedObjectContext)

            reservoir.volume = unitVolume
            reservoir.date = date

            let previousValue = self.lastStoredReservoirValue
            if let basalProfile = self.basalProfile {
                var newValues: [StoredReservoirValue] = []

                if let previousValue = previousValue {
                    newValues.append(previousValue)
                }

                newValues.append(reservoir.storedReservoirValue)

                let newDoseEntries = newValues.doseEntries

                if self.recentReservoirNormalizedDoseEntriesCache != nil {
                    self.recentReservoirNormalizedDoseEntriesCache = self.recentReservoirNormalizedDoseEntriesCache!.filterDateRange(self.cacheStartDate, nil)

                    self.recentReservoirNormalizedDoseEntriesCache! += newDoseEntries.annotated(with: basalProfile)
                }

                /// Increment the total delivery cache
                if let totalDelivery = self.totalDeliveryCache {
                    self.totalDeliveryCache = InsulinValue(
                        startDate: totalDelivery.startDate,
                        value: totalDelivery.value + newDoseEntries.totalDelivery
                    )
                }
            }

            // Remove reservoir objects older than our cache length
            try? self.purgeReservoirObjects(matching: self.purgeableValuesPredicate)
            // Trigger a re-evaluation of continuity and update self.lastStoredReservoirValue
            self.validateReservoirContinuity()

            // Reset our mutable pump events, since they are considered in addition to reservoir in dosing
            if self.areReservoirValuesValid {
                self.mutablePumpEventDoses = self.mutablePumpEventDoses.filterDateRange(Date(), nil)
            }

            self.persistenceController.save { (error) -> Void in
                var saveError: DoseStoreError?

                if let error = error {
                    saveError = DoseStoreError(error: error)
                }

                completion(
                    reservoir.storedReservoirValue,
                    previousValue,
                    self.areReservoirValuesValid,
                    saveError
                )

                NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)
            }
        }
    }

    /// Retrieves reservoir values since the given date.
    ///
    /// - Parameters:
    ///   - startDate: The earliest reservoir record date to include
    ///   - completion: A closure called after retrieval
    ///   - result: An array of reservoir values in reverse-chronological order
    public func getReservoirValues(since startDate: Date, completion: @escaping (_ result: DoseStoreResult<[ReservoirValue]>) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                let values = try self.getReservoirObjects(since: startDate).map { $0.storedReservoirValue }

                completion(.success(values))
            } catch let error as DoseStoreError {
                completion(.failure(error))
            } catch {
                assertionFailure()
            }
        }
    }

    /// *This method should only be called from within a managed object context block.*
    ///
    /// - Parameter startDate: The earliest reservoir record date to include
    /// - Returns: An array of reservoir managed objects, in reverse-chronological order
    /// - Throws: An error describing the failure to fetch objects
    private func getReservoirObjects(since startDate: Date) throws -> [Reservoir] {
        let request: NSFetchRequest<Reservoir> = Reservoir.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

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
    /// - Returns: An array of normalizd entries
    /// - Throws: A DoseStoreError describing a failure
    private func getNormalizedReservoirDoseEntries(start: Date, end: Date? = nil) throws -> [DoseEntry] {
        if let normalizedDoses = self.recentReservoirNormalizedDoseEntriesCache, let firstDoseDate = normalizedDoses.first?.startDate, firstDoseDate <= start {
            return normalizedDoses.filterDateRange(start, end)
        } else {
            guard let basalProfile = self.basalProfile else {
                throw DoseStoreError.configurationError
            }

            let doses = try self.getReservoirObjects(since: start).reversed().doseEntries

            let normalizedDoses = doses.annotated(with: basalProfile)
            self.recentReservoirNormalizedDoseEntriesCache = normalizedDoses
            return normalizedDoses.filterDateRange(start, end)
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
        persistenceController.managedObjectContext.perform { [unowned self] in
            var deletedObjects = [ReservoirValue]()
            if  let storedValue = value as? StoredReservoirValue,
                let objectID = self.persistenceController.managedObjectContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: storedValue.objectIDURL),
                let object = try? self.persistenceController.managedObjectContext.existingObject(with: objectID)
            {
                self.persistenceController.managedObjectContext.delete(object)
                deletedObjects.append(storedValue)
                self.validateReservoirContinuity()
            }

            self.persistenceController.save { (error) in
                self.clearReservoirNormalizedDoseCache()
                completion(deletedObjects, DoseStoreError(error: error))
                NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)
            }
        }
    }

    /// Deletes all persisted reservoir values
    ///
    /// - Parameter completion: A closure called after all the values are deleted. This closure takes a single argument:
    /// - Parameter error: An error explaining why the deletion failed
    public func deleteAllReservoirValues(_ completion: @escaping (_ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                self.log.info("Deleting all reservoir values")
                try self.purgeReservoirObjects()

                self.persistenceController.save { (error) in
                    self.totalDeliveryCache = nil
                    self.clearReservoirNormalizedDoseCache()
                    self.validateReservoirContinuity()

                    completion(DoseStoreError(error: error))
                    NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)
                }
            } catch let error as PersistenceController.PersistenceControllerError {
                completion(DoseStoreError(error: error))
            } catch {
                assertionFailure()
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
    /// Get the date of the last prime event. Updates from Core Data if value is invalid
    ///
    /// *This method should only be called from within a managed object context block*
    ///
    /// - Returns: Date of the last prime event, or distant past if none found
    private func getLastPrimeEventDate() -> Date {
        if _lastRecordedPrimeEventDate == nil {
            if  let pumpEvents = try? self.getPumpEventObjects(
                    matching: NSPredicate(format: "type = %@", PumpEventType.prime.rawValue),
                    chronological: false
                ),
                let firstEvent = pumpEvents.first
            {
                _lastRecordedPrimeEventDate = firstEvent.date
            } else {
                _lastRecordedPrimeEventDate = .distantPast
            }
        }

        return _lastRecordedPrimeEventDate ?? .distantPast
    }

    /**
     Adds and persists new pump events.
     
     Events are deduplicated by a unique constraint on `NewPumpEvent.getter:raw`.

     - parameter events:     An array of new pump events
     - parameter completion: A closure called after the events are saved. The closure takes a single argument:
     - parameter error: An error object explaining why the events could not be saved.
     */
    public func addPumpEvents(_ events: [NewPumpEvent], completion: @escaping (_ error: DoseStoreError?) -> Void) {
        // Consider an empty events array as a successful add
        lastAddedPumpEvents = Date()

        guard events.count > 0 else {
            completion(nil)
            return
        }

        persistenceController.managedObjectContext.perform { [unowned self] in
            var lastFinalDate: Date?
            var firstMutableDate: Date?
            var primeValueAdded = false

            var mutablePumpEventDoses: [DoseEntry] = []

            // There is no guarantee of event ordering, so we must search the entire array to find key date boundaries.
            for event in events {
                if case .prime? = event.type {
                    primeValueAdded = true
                }
                
                if event.isMutable {
                    firstMutableDate = min(event.date, firstMutableDate ?? event.date)

                    if let dose = event.dose {
                        mutablePumpEventDoses.append(dose)
                    }
                } else {
                    lastFinalDate = max(event.date, lastFinalDate ?? event.date)

                    let object = PumpEvent(entity: PumpEvent.entity(), insertInto: self.persistenceController.managedObjectContext)

                    object.date = event.date
                    object.raw = event.raw
                    object.title = event.title
                    object.type = event.type
                    object.dose = event.dose
                }
            }

            // This is a hack to prevent doubling up mutable doses on a MM x23+ model pump.
            // Assume it's safe to override any pre-reported pending doses if a new history read found mutable doses.
            if mutablePumpEventDoses.count > 0 {
                self.mutablePumpEventDoses = mutablePumpEventDoses
            } else {
                self.mutablePumpEventDoses = self.mutablePumpEventDoses.filterDateRange(self.lastAddedPumpEvents, nil)
            }

            if let mutableDate = firstMutableDate {
                self.pumpEventQueryAfterDate = mutableDate
            } else if let finalDate = lastFinalDate {
                self.pumpEventQueryAfterDate = finalDate
            }

            if primeValueAdded {
                self.invalidateLastPrimeEventDate()
                self.validateReservoirContinuity()
            }

            self.persistenceController.save { [unowned self] (error) -> Void in
                completion(DoseStoreError(error: error))
                NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)
                self.uploadPumpEventsIfNeeded()

                self.syncPumpEventsToHealthStore()
            }
        }
    }

    /// Appends a temporary pump event to be considered in dose calculation.
    ///
    /// Events added using this method will be cleared during calls to `addPumpEvents(_:completion:)` and `addReservoirValue(_:atDate:completion:)`
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - event: The event to append
    ///   - completion: A closure called when the add has completed
    public func addPendingPumpEvent(_ event: NewPumpEvent, completion: @escaping () -> Void) {
        persistenceController.managedObjectContext.perform { [unowned self] in
            if let dose = event.dose {
                self.mutablePumpEventDoses.append(dose)
            }

            completion()
        }
    }

    public func deletePumpEvent(_ event: PersistedPumpEvent, completion: @escaping (_ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform { [unowned self] in
            if let object = try? self.persistenceController.managedObjectContext.existingObject(with: event.objectID) {
                self.persistenceController.managedObjectContext.delete(object)
            }

            // Reset the latest query date to the newest PumpEvent
            let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.fetchLimit = 1

            if let events = try? self.persistenceController.managedObjectContext.fetch(request),
                let lastEvent = events.first
            {
                self.pumpEventQueryAfterDate = lastEvent.date
            } else {
                self.pumpEventQueryAfterDate = self.recentValuesStartDate
            }

            self.persistenceController.save { (error) in
                completion(DoseStoreError(error: error))
                NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)
                
                self.invalidateLastPrimeEventDate()
                self.validateReservoirContinuity()
            }
        }
    }

    /// Deletes all persisted pump events
    ///
    /// - Parameter completion: A closure called after all the events are deleted. This closure takes a single argument:
    /// - Parameter error: An error explaining why the deletion failed
    public func deleteAllPumpEvents(_ completion: @escaping (_ error: DoseStoreError?) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                self.log.info("Deleting all pump events")
                try self.purgePumpEventObjects()

                self.persistenceController.save { (error) in
                    self.pumpEventQueryAfterDate = self.recentValuesStartDate
                    self.lastAddedPumpEvents = .distantPast
                    self.invalidateLastPrimeEventDate()

                    completion(DoseStoreError(error: error))
                    NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)
                }
            } catch let error as PersistenceController.PersistenceControllerError {
                completion(DoseStoreError(error: error))
            } catch {
                assertionFailure()
            }
        }
    }

    /// Attempts to store doses from pump events to Health
    /// *This method should only be called from within a managed object context block*
    private func syncPumpEventsToHealthStore() {
        insulinDeliveryStore.getLastBasalEndDate { (result) in
            switch result {
            case .success(let date):
                // Limit the query behavior to 24 hours
                let date = max(date, self.cacheStartDate)
                self.savePumpEventsToHealthStore(after: date)
            case .failure:
                // Failures are expected when the health database is protected
                break
            }
        }
    }

    /// Processes and saves dose events on or after the given date to Health
    ///
    /// - Parameter start: The date at which
    private func savePumpEventsToHealthStore(after start: Date) {
        self.persistenceController.managedObjectContext.perform {
            guard let doses = try? self.getNormalizedPumpEventDoseEntries(start: start),
                doses.count > 0,
                let basalSchedule = self.basalProfile
            else {
                return
            }

            let reconciledDoses = doses.overlayBasalSchedule(basalSchedule, startingAt: start, endingAt: self.lastAddedPumpEvents, insertingBasalEntries: !self.pumpRecordsBasalProfileStartEvents)
            self.insulinDeliveryStore.addReconciledDoses(reconciledDoses, from: self.device) { (result) in
                if case .failure(let error) = result {
                    self.log.error("Error adding doses: %{public}@", String(describing: error))
                }
            }
        }
    }

    /**
     Asks the delegate to upload all non-uploaded pump events, and updates the store when the delegate calls its completion handler.

     *This method should only be called from within a managed object context block.*
     */
    private func uploadPumpEventsIfNeeded() {
        guard !isUploadRequestPending, let delegate = delegate else {
            return
        }

        guard let objects = try? getPumpEventObjects(matching: NSPredicate(format: "uploaded = false"), chronological: true), objects.count > 0 else {
            return
        }

        let events = objects.map { $0.persistedPumpEvent }
        isUploadRequestPending = true

        delegate.doseStore(self, hasEventsNeedingUpload: events) { (uploadedObjects) in
            self.persistenceController.managedObjectContext.perform { [unowned self] in
                for id in uploadedObjects {
                    guard let object = try? self.persistenceController.managedObjectContext.existingObject(with: id), let event = object as? PumpEvent else {
                        continue
                    }

                    event.uploaded = true
                }

                // Remove uploaded events older than the
                let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [self.purgeableValuesPredicate,
                                                                                    NSPredicate(format: "uploaded = true")])
                try? self.purgePumpEventObjects(matching: predicate)

                self.persistenceController.save()

                self.isUploadRequestPending = false
            }
        }
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
    ///   - chronological: Whether to return the objects in chronological or reverse-chronological order
    /// - Returns: An array of pump events in the specified order by date
    /// - Throws: An error describing the failure to fetch objects
    private func getPumpEventObjects(matching predicate: NSPredicate, chronological: Bool) throws -> [PumpEvent] {
        let request: NSFetchRequest<PumpEvent> = PumpEvent.fetchRequest()
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: chronological)]

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
        guard let basalProfile = self.basalProfile else {
            throw DoseStoreError.configurationError
        }

        let doses = try getPumpEventObjects(
            matching: NSPredicate(format: "date >= %@ && type != nil", start as NSDate),
            chronological: true
        ).flatMap({ $0.dose })
        let normalizedDoses = doses.reconcile().annotated(with: basalProfile)

        return normalizedDoses.filterDateRange(start, end)
    }

    /**
     Removes uploaded pump event objects older than the recency predicate

     *This method should only be called from within a managed object context block.*

     - throws: A core data exception if the delete request failed
     */
    private func purgePumpEventObjects(matching predicate: NSPredicate? = nil) throws {
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
        }
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
    public func getNormalizedDoseEntries(start: Date, end: Date? = nil, completion: @escaping (_ result: DoseStoreResult<[DoseEntry]>) -> Void) {
        persistenceController.managedObjectContext.perform {
            do {
                let doses: [DoseEntry]
                // Reservoir data is used only if its continuous and we haven't seen pump events since the last reservoir reading
                if self.areReservoirValuesValid &&
                    self.lastAddedPumpEvents.timeIntervalSince(self.lastStoredReservoirValue?.startDate ?? .distantPast) < 0 {
                    doses = try self.getNormalizedReservoirDoseEntries(start: start, end: end)
                } else {
                    doses = try self.getNormalizedPumpEventDoseEntries(start: start, end: end)
                }

                completion(.success(doses + self.mutablePumpEventDoses))
            } catch let error as DoseStoreError {
                completion(.failure(error))
            } catch {
                assertionFailure()
            }
        }
    }

    /// Retrieves the single insulin on-board value occuring just prior to the specified date
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - date: The date of the value to retrieve
    ///   - completion: A closure called once the value has been retrieved
    ///   - result: The insulin on-board value
    public func insulinOnBoard(at date: Date, completion: @escaping (_ result: DoseStoreResult<InsulinValue>) -> Void) {
        getInsulinOnBoardValues(start: date.addingTimeInterval(TimeInterval(minutes: -5)), end: date) { (result) -> Void in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let values):
                guard let value = values.closestPriorToDate(date) else {
                    completion(.failure(.fetchError(description: "No values found", recoverySuggestion: "Ensure insulin data exists for the specified date")))
                    return
                }
                completion(.success(value))
            }
        }
    }

    /// Retrieves a timeline of unabsorbed insulin values.
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - start: The earliest date of values to retrieve
    ///   - end: The latest date of values to retrieve, if provided
    ///   - basalDosingEnd: The date at which continuing doses should be assumed to be cancelled
    ///   - completion: A closure called once the values have been retrieved
    ///   - result: An array of insulin values, in chronological order
    public func getInsulinOnBoardValues(start: Date, end: Date? = nil, basalDosingEnd: Date? = nil, completion: @escaping (_ result: DoseStoreResult<[InsulinValue]>) -> Void) {
        guard let insulinModel = self.insulinModel else {
            completion(.failure(.configurationError))
            return
        }

        // To properly know IOB at startDate, we need to go back another DIA hours
        let doseStart = start.addingTimeInterval(-insulinModel.effectDuration)
        getNormalizedDoseEntries(start: doseStart, end: end) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let doses):
                let trimmedDoses = doses.map { $0.trim(to: basalDosingEnd) }
                let insulinOnBoard = trimmedDoses.insulinOnBoard(model: insulinModel)
                completion(.success(insulinOnBoard.filterDateRange(start, end)))
            }
        }
    }

    /// Retrieves a timeline of effect on blood glucose from doses
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - Parameters:
    ///   - start: The earliest date of effects to retrieve
    ///   - end: The latest date of effects to retrieve, if provided
    ///   - basalDosingEnd: The date at which continuing doses should be assumed to be cancelled
    ///   - completion: A closure called once the effects have been retrieved
    ///   - result: An array of effects, in chronological order
    public func getGlucoseEffects(start: Date, end: Date? = nil, basalDosingEnd: Date? = Date(), completion: @escaping (_ result: DoseStoreResult<[GlucoseEffect]>) -> Void) {
        guard let insulinModel = self.insulinModel,
              let insulinSensitivitySchedule = self.insulinSensitivitySchedule
        else {
            completion(.failure(.configurationError))
            return
        }

        // To properly know glucose effects at startDate, we need to go back another DIA hours
        let doseStart = start.addingTimeInterval(-insulinModel.effectDuration)
        getNormalizedDoseEntries(start: doseStart, end: end) { (result) in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let doses):
                let trimmedDoses = doses.map { $0.trim(to: basalDosingEnd) }
                let glucoseEffects = trimmedDoses.glucoseEffects(insulinModel: insulinModel, insulinSensitivity: insulinSensitivitySchedule)
                completion(.success(glucoseEffects.filterDateRange(start, end)))
            }
        }
    }

    /// Retrieves the estimated total number of units delivered since the specified date.
    ///
    /// - Parameters:
    ///   - startDate: The date after which delivery should be calculated
    ///   - completion: A closure called once the total has been retrieved with arguments:
    ///   - result: The total units delivered and the date of the first dose
    public func getTotalUnitsDelivered(since startDate: Date, completion: @escaping (_ result: DoseStoreResult<InsulinValue>) -> Void) {
        persistenceController.managedObjectContext.perform {
            if  let totalDeliveryCache = self.totalDeliveryCache,
                totalDeliveryCache.startDate >= startDate
            {
                completion(.success(totalDeliveryCache))
                return
            }

            do {
                let doses = try self.getNormalizedReservoirDoseEntries(start: startDate)
                let result = InsulinValue(
                    startDate: doses.first?.startDate ?? Date(),
                    value: doses.totalDelivery
                )

                if doses.count > 0 {
                    self.totalDeliveryCache = result
                }

                completion(.success(result))
            } catch let error as DoseStoreError {
                completion(.failure(error))
            } catch {
                assertionFailure()
            }
        }
    }
}

extension DoseStore {
    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completion: The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completion: @escaping (_ report: String) -> Void) {
        var report: [String] = [
            "## DoseStore",
            "",
            "* readyState: \(readyState)",
            "* insulinModel: \(String(reflecting: insulinModel))",
            "* basalProfile: \(basalProfile?.debugDescription ?? "")",
            "* insulinSensitivitySchedule: \(insulinSensitivitySchedule?.debugDescription ?? "")",
            "* areReservoirValuesValid: \(areReservoirValuesValid)",
            "* isUploadRequestPending: \(isUploadRequestPending)",
            "* lastAddedPumpEvents: \(lastAddedPumpEvents)",
            "* lastStoredReservoirValue: \(String(describing: lastStoredReservoirValue))",
            "* mutablePumpEventDoses: \(mutablePumpEventDoses)",
            "* pumpEventQueryAfterDate: \(pumpEventQueryAfterDate)",
            "* totalDeliveryCache: \(String(describing: totalDeliveryCache))",
            "* lastPrimeEventDate: \(String(describing: _lastRecordedPrimeEventDate))",
            "* pumpRecordsBasalProfileStartEvents: \(pumpRecordsBasalProfileStartEvents)",
            "* device: \(String(describing: device))",
        ]

        getReservoirValues(since: Date.distantPast) { (result) in
            report.append("")
            report.append("### getReservoirValues")

            switch result {
            case .failure(let error):
                report.append("Error: \(error)")
            case .success(let values):
                report.append("")
                for value in values {
                    report.append("* \(value.startDate), \(value.unitVolume)")
                }
            }

            self.getPumpEventValues(since: Date.distantPast) { (result) in
                report.append("")
                report.append("### getRecentPumpEventValues")

                switch result {
                case .failure(let error):
                    report.append("Error: \(error)")
                case .success(let values):
                    report.append("")
                    for value in values {
                        report.append("* \(value)")
                    }
                }

                self.getNormalizedDoseEntries(start: Date.distantPast) { (result) in
                    report.append("")
                    report.append("### getNormalizedDoseEntries")

                    switch result {
                    case .failure(let error):
                        report.append("Error: \(error)")
                    case .success(let entries):
                        report.append("")
                        for entry in entries {
                            report.append("* \(entry)")
                        }
                    }

                    self.insulinDeliveryStore.generateDiagnosticReport { (result) in
                        report.append("")
                        report.append(result)

                        report.append("")
                        completion(report.joined(separator: "\n"))
                    }
                }
            }
        }
    }
}
