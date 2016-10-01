//
//  DoseStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/27/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import CoreData
import LoopKit


public protocol DoseStoreDelegate: class {
    /**
     Asks the delegate to upload recently-added pump events not yet marked as uploaded.
     
     The completion handler must be called in all circumstances, with an array of object IDs that were successfully uploaded and can be purged when they are no longer recent.
     
     - parameter doseStore:  The store instance
     - parameter pumpEvents: The pump events
     - parameter pumpID:     The ID of the pump
     - parameter completionHandler: The closure to execute when the upload attempt has finished. The closure takes a single argument of an array of object IDs that were successfully uploaded. If the upload did not succeed, call the closure with an empty array.
     */
    func doseStore(_ doseStore: DoseStore, hasEventsNeedingUpload pumpEvents: [PersistedPumpEvent], fromPumpID pumpID: String, withCompletion completionHandler: @escaping (_ uploadedObjects: [NSManagedObjectID]) -> Void)
}


public extension NSNotification.Name {
    /// Notification posted when the ready state was modified.
    public static let DoseStoreReadyStateDidChange = NSNotification.Name(rawValue: "com.loudnate.InsulinKit.ReadyStateDidUpdateNotification")

    /// Notification posted when data was modifed.
    public static let DoseStoreValuesDidChange = NSNotification.Name(rawValue: "com.loudnate.InsulinKit.ValuesDidChangeNotification")
}


/**
 Manages storage, retrieval, and calculation of insulin pump delivery data.
 
 Pump data are stored in the following tiers:
 
 * In-memory cache, used for IOB and insulin effect calculation
 ```
 0            [min(1 day ago, 1.5 * insulinActionDuration)]
 |––––––––––––––––––––—————————––|
 ```
 * On-disk Core Data store, accessible after first unlock
 ```
 0            [min(1 day ago, 1.5 * insulinActionDuration)]
 |––––––––––––––––––––––—————————|
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
        case initializationError(description: String, recoverySuggestion: String)
        case persistenceError(description: String, recoverySuggestion: String?)
        case fetchError(description: String, recoverySuggestion: String?)
    }

    public var pumpID: String? {
        didSet {
            guard pumpID != oldValue else {
                return
            }

            persistenceController?.managedObjectContext.perform {
                self.clearReservoirCache()
                self.pumpEventQueryAfterDate = self.recentValuesStartDate ?? Date.distantPast
            }
            configurationDidChange()
        }
    }

    public weak var delegate: DoseStoreDelegate? {
        didSet {
            isUploadRequestPending = false
        }
    }

    public var insulinActionDuration: TimeInterval? {
        didSet {
            persistenceController?.managedObjectContext.perform {
                self.clearCalculationCache()

                if let recentValuesStartDate = self.recentValuesStartDate {
                    self.pumpEventQueryAfterDate = max(self.pumpEventQueryAfterDate, recentValuesStartDate)
                }
            }

            configurationDidChange()
        }
    }

    public var basalProfile: BasalRateSchedule? {
        didSet {
            persistenceController?.managedObjectContext.perform {
                self.clearReservoirNormalizedDoseCache()
                self.clearPumpEventNormalizedDoseCache()
            }
        }
    }

    public var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        didSet {
            persistenceController?.managedObjectContext.perform {
                self.clearCalculationCache()
            }
        }
    }

    public init(pumpID: String?, insulinActionDuration: TimeInterval?, basalProfile: BasalRateSchedule?, insulinSensitivitySchedule: InsulinSensitivitySchedule?) {
        self.pumpID = pumpID
        self.insulinActionDuration = insulinActionDuration
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
        self.basalProfile = basalProfile
        self.pumpEventQueryAfterDate = recentValuesStartDate ?? Date.distantPast

        configurationDidChange()
    }

    private func configurationDidChange() {
        if insulinActionDuration != nil && pumpID != nil {
            initializePersistenceController()
        } else {
            readyState = .needsConfiguration
        }
    }

    private func initializePersistenceController() {
        if persistenceController == nil, case .needsConfiguration = readyState {
            readyState = .initializing

            persistenceController = PersistenceController(readyCallback: { [unowned self] (error) -> Void in
                if let error = error {
                    self.readyState = .failed(.initializationError(description: error.localizedDescription, recoverySuggestion: error.recoverySuggestion))
                } else {
                    if  let context = self.persistenceController?.managedObjectContext,
                        let pumpID = self.pumpID
                    {
                        // Find the newest PumpEvent date we have


                        if let lastEvent = PumpEvent.singleObjectInContext(context,
                            predicate: NSPredicate(format: "pumpID = %@", pumpID),
                            sortedBy: "date",
                            ascending: false
                        ) {
                            self.pumpEventQueryAfterDate = lastEvent.date
                        }

                        // Warm the state of the reservoir data
                        if let recentReservoirObjects = try? self.getRecentReservoirObjects() {
                            // These are in reverse-chronological order. 
                            // To populate `lastReservoirVolumeDrop`, we set the most recent 2 in-order.
                            if recentReservoirObjects.count > 1 {
                                self.lastReservoirObject = recentReservoirObjects[1]
                            }

                            self.lastReservoirObject = recentReservoirObjects.first

                            if let insulinActionDuration = self.insulinActionDuration {
                                self.areReservoirValuesContinuous = InsulinMath.isContinuous(recentReservoirObjects.reversed(), from: Date(timeIntervalSinceNow: -insulinActionDuration))
                            }
                        }
                    }

                    self.readyState = .ready
                }
            })
        } else {
            readyState = .ready
        }
    }

    private var persistenceController: PersistenceController?

    private var recentValuesPredicate: NSPredicate? {
        if let pumpID = pumpID, let startDate = recentValuesStartDate {
            let predicate = NSPredicate(format: "date >= %@ && pumpID = %@", startDate as CVarArg, pumpID)

            return predicate
        } else {
            return nil
        }
    }

    private var purgeableValuesPredicate: NSPredicate? {
        if let pumpID = pumpID, let startDate = recentValuesStartDate {
            let predicate = NSPredicate(format: "date < %@", startDate as CVarArg, pumpID)

            return predicate
        } else {
            return nil
        }
    }

    // MARK: - Reservoir Data

    // Whether the current recent state of the stored reservoir data is considered 
    // continuous and reliable for the derivation of insulin effects
    public private(set) var areReservoirValuesContinuous = false

    /// The last-created reservoir object.
    /// *This setter should only be called from within a managed object context block.*
    private var lastReservoirObject: Reservoir? {
        didSet {
            if let oldValue = oldValue, let newValue = lastReservoirObject {
                lastReservoirVolumeDrop = oldValue.unitVolume - newValue.unitVolume
            }
        }
    }

    // The last change in reservoir volume.
    public private(set) var lastReservoirVolumeDrop: Double = 0

    // The last-saved reservoir value
    public var lastReservoirValue: ReservoirValue? {
        return lastReservoirObject
    }

    private var recentReservoirNormalizedDoseEntriesCache: [DoseEntry]?

    private var recentReservoirDoseEntriesCache: [DoseEntry]?

    private var recentValuesStartDate: Date? {
        if let insulinActionDuration = insulinActionDuration {
            let calendar = Calendar.current

            return min(calendar.startOfDay(for: Date()), Date(timeIntervalSinceNow: -insulinActionDuration * 3 / 2 - TimeInterval(minutes: 5)))
        } else {
            return nil
        }
    }

    /**
     Adds and persists a new reservoir value

     - parameter unitVolume:        The reservoir volume, in units
     - parameter date:              The date of the volume reading
     - parameter completionHandler: A closure called after the value was saved. This closure takes three arguments:
        - value:                    The new reservoir value, if it was saved
        - previousValue:            The last new reservoir value
        - areStoredValuesContinous: Whether the current recent state of the stored reservoir data is considered continuous and reliable for deriving insulin effects after addition of this new value.
        - error:                    An error object explaining why the value could not be saved
     */
    public func addReservoirValue(_ unitVolume: Double, atDate date: Date, completionHandler: @escaping (_ value: ReservoirValue?, _ previousValue: ReservoirValue?, _ areStoredValuesContinuous: Bool, _ error: DoseStoreError?) -> Void) {
        guard let pumpID = pumpID, let persistenceController = persistenceController else {
            completionHandler(nil, nil, false, .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            let reservoir = Reservoir.insertNewObjectInContext(persistenceController.managedObjectContext)

            reservoir.volume = unitVolume
            reservoir.date = date
            reservoir.pumpID = pumpID

            var previousValue: Reservoir?
            if  let doseEntries = try? self.getRecentReservoirDoseEntries(),
                let basalProfile = self.basalProfile,
                let minEndDate = self.recentValuesStartDate
            {
                var recentDoseEntries = doseEntries.filterDateRange(minEndDate, nil)

                var newValues: [Reservoir] = []

                previousValue = self.lastReservoirObject

                if let previousValue = previousValue {
                    newValues.append(previousValue)
                }

                newValues.append(reservoir)

                let newDoseEntries = InsulinMath.doseEntriesFromReservoirValues(newValues)
                recentDoseEntries += newDoseEntries

                // Consider any entries longer than 30 minutes, or with a value of 0, to be unreliable; warn the caller they might want to try a different data source.
                if let insulinActionDuration = self.insulinActionDuration,
                    let recentReservoirObjects = try? self.getRecentReservoirObjects()
                {
                    self.areReservoirValuesContinuous = InsulinMath.isContinuous(recentReservoirObjects.reversed(), from: Date(timeIntervalSinceNow: -insulinActionDuration))
                }

                self.recentReservoirDoseEntriesCache = recentDoseEntries

                if self.recentReservoirNormalizedDoseEntriesCache != nil {
                    self.recentReservoirNormalizedDoseEntriesCache = self.recentReservoirNormalizedDoseEntriesCache!.filterDateRange(minEndDate, nil)

                    self.recentReservoirNormalizedDoseEntriesCache! += InsulinMath.normalize(newDoseEntries, againstBasalSchedule: basalProfile)
                }
            }

            self.lastReservoirObject = reservoir

            self.clearCalculationCache()

            persistenceController.save { (error) -> Void in
                if let error = error {
                    completionHandler(
                        reservoir,
                        previousValue,
                        self.areReservoirValuesContinuous,
                        .persistenceError(description: error.description, recoverySuggestion: error.recoverySuggestion)
                    )
                } else {
                    completionHandler(
                        reservoir,
                        previousValue,
                        self.areReservoirValuesContinuous,
                        nil
                    )
                }

                NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)

                do {
                    try self.purgeReservoirObjects()
                } catch {
                }
            }
        }
    }

    /**
     Fetches recent reservoir values

     - parameter resultsHandler: A closure called when the results are ready. This closure takes two arguments:
        - objects: An array of reservoir values in reverse-chronological order
        - error:   An error object explaining why the results could not be fetched
     */
    public func getRecentReservoirValues(_ resultsHandler: @escaping (_ values: [ReservoirValue], _ error: DoseStoreError?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler([], .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            do {
                let objects = try self.getRecentReservoirObjects()

                resultsHandler(objects.map({ $0 as ReservoirValue}), nil)
            } catch let error as DoseStoreError {
                resultsHandler([], error)
            } catch {
                assertionFailure()
            }
        }
    }

    /**
     *This method should only be called from within a managed object context block.*

     - throws: An error describing the failure to fetch objects
     
     - returns: An array of recently saved reservoir managed objects, in reverse-chronological order
     */
    private func getRecentReservoirObjects() throws -> [Reservoir] {
        do {
            return try Reservoir.objectsInContext(persistenceController!.managedObjectContext, predicate: self.recentValuesPredicate, sortedBy: "date", ascending: false)
        } catch let fetchError as NSError {
            throw DoseStoreError.fetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
        }
    }

    /**
     *This method should only be called from within a managed object context block.*

     - throws: An error describing the failure to fetch reservoir data

     - returns: An array of dose entries, derived from recorded reservoir values
     */
    private func getRecentReservoirDoseEntries() throws -> [DoseEntry] {
        if let doses = self.recentReservoirDoseEntriesCache {
            return doses
        } else {
            let objects = try self.getRecentReservoirObjects()

            self.recentReservoirDoseEntriesCache = InsulinMath.doseEntriesFromReservoirValues(objects.reversed())
            return self.recentReservoirDoseEntriesCache ?? []
        }
    }

    /**
     Retrieves recent dose values derived from reservoir readings.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:      The earliest date of entries to retrieve. The default, and earliest supported value, is the earlier of the current date less `insulinActionDuration` or the previous midnight in the current time zone.
     - parameter endDate:        The latest date of entries to retrieve. Defaults to the distant future.
     - parameter resultsHandler: A closure called once the entries have been retrieved. The closure takes two arguments:
        - doses: The retrieved entries
        - error: An error object explaining why the retrieval failed
     */
    func getRecentNormalizedReservoirDoseEntries(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ doses: [DoseEntry], _ error: DoseStoreError?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler([], .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            if let normalizedDoses = self.recentReservoirNormalizedDoseEntriesCache {
                resultsHandler(normalizedDoses.filterDateRange(startDate, endDate), nil)
            } else {
                if let basalProfile = self.basalProfile {
                    do {
                        let doses = try self.getRecentReservoirDoseEntries()

                        let normalizedDoses = InsulinMath.normalize(doses, againstBasalSchedule: basalProfile)
                        self.recentReservoirNormalizedDoseEntriesCache = normalizedDoses
                        resultsHandler(normalizedDoses.filterDateRange(startDate, endDate), nil)
                    } catch let error as DoseStoreError {
                        resultsHandler([], error)
                    } catch {
                        assertionFailure()
                    }
                } else {
                    resultsHandler([], .configurationError)
                }
            }
        }
    }

    /**
     Deletes a persisted reservoir value

     - parameter value:             The value to delete
     - parameter completionHandler: A closure called after the value was deleted. This closure takes two arguments:
        - deletedValues: An array of removed values
        - error:         An error object explaining why the value could not be deleted
     */
    public func deleteReservoirValue(_ value: ReservoirValue, completionHandler: @escaping (_ deletedValues: [ReservoirValue], _ error: DoseStoreError?) -> Void) {
        guard let persistenceController = persistenceController else {
            completionHandler([], .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            var deletedObjects = [Reservoir]()
            var error: DoseStoreError?

            if let object = value as? Reservoir {
                self.deleteReservoirObject(object)
                deletedObjects.append(object)
            } else if let pumpID = self.pumpID {
                // TODO: Unecessary case handling?
                let predicate = NSPredicate(format: "date = %@ && pumpID = %@", value.startDate as NSDate, pumpID)

                do {
                    for object in try Reservoir.objectsInContext(persistenceController.managedObjectContext, predicate: predicate) {
                        self.deleteReservoirObject(object)
                        deletedObjects.append(object)
                    }
                } catch let deleteError as NSError {
                    error = .persistenceError(description: deleteError.localizedDescription, recoverySuggestion: deleteError.localizedRecoverySuggestion)
                }
            }

            self.clearReservoirDoseCache()
            completionHandler(deletedObjects.map { $0 }, error)

            NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)
        }
    }

    /**
     Deletes a specified reservoir object from the context and removes it from the cache

     *This method should only be called from within a managed object context block.*

     - parameter object: The object to delete
     */
    private func deleteReservoirObject(_ object: Reservoir) {
        persistenceController?.managedObjectContext.delete(object)
    }

    /**
     Removes reservoir objects older than the recency predicate

     *This method should only be called from within a managed object context block.*

     - throws: A core data exception if the delete request failed
     */
    private func purgeReservoirObjects() throws {
        guard let predicate = purgeableValuesPredicate, let persistenceController = persistenceController else {
            throw DoseStoreError.configurationError
        }

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Reservoir.entityName())
        fetchRequest.predicate = predicate
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        deleteRequest.resultType = .resultTypeCount

        if let result = try persistenceController.managedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult, let count = result.result as? Int, count > 0 {
            persistenceController.managedObjectContext.refreshAllObjects()
        }
    }

    // MARK: - Pump Event Data

    /// The earliest event date that should included in subsequent queries for pump event data.
    public private(set) var pumpEventQueryAfterDate = Date.distantPast

    /// The last time `addPumpEvents` was called, used to estimate recency of data.
    private var lastAddedPumpEvents = Date.distantPast

    /// A cache of existing normalized dose entries
    private var recentPumpEventNormalizedDoseEntriesCache: [DoseEntry]?

    /// The last-seen mutable pump events, which aren't persisted but are used for dose calculation.
    private var mutablePumpEventDoses: [DoseEntry]?

    /**
     Adds and persists new pump events.
     
     Events are deduplicated by a unique constraint of pump ID, date, and raw data.

     - parameter events:            An array of new pump events
     - parameter completionHandler: A closure called after the events are saved. The closure takes a single argument:
        - error: An error object explaining why the events could not be saved.
     */
    public func addPumpEvents(_ events: [NewPumpEvent], completionHandler: @escaping (_ error: DoseStoreError?) -> Void) {
        lastAddedPumpEvents = Date()

        guard let pumpID = pumpID, let persistenceController = persistenceController else {
            completionHandler(.configurationError)
            return
        }

        guard events.count > 0 else {
            completionHandler(nil)
            return
        }

        persistenceController.managedObjectContext.perform {
            var lastFinalDate: Date?
            var firstMutableDate: Date?

            var mutablePumpEventDoses: [DoseEntry] = []

            for event in events {
                if event.isMutable {
                    firstMutableDate = min(event.date as Date, firstMutableDate ?? event.date as Date)

                    if let dose = event.dose {
                        mutablePumpEventDoses.append(dose)
                    }
                } else {
                    lastFinalDate = max(event.date as Date, lastFinalDate ?? event.date as Date)

                    let object = PumpEvent.insertNewObjectInContext(persistenceController.managedObjectContext)

                    object.date = event.date
                    object.raw = event.raw
                    object.dose = event.dose
                    object.title = event.title
                    object.pumpID = pumpID
                }
            }

            self.mutablePumpEventDoses = mutablePumpEventDoses

            if let mutableDate = firstMutableDate {
                self.pumpEventQueryAfterDate = mutableDate
            } else if let finalDate = lastFinalDate {
                self.pumpEventQueryAfterDate = finalDate
            }

            self.clearPumpEventNormalizedDoseCache()

            persistenceController.save { (error) -> Void in
                if let error = error {
                    completionHandler(.persistenceError(description: error.description, recoverySuggestion: error.recoverySuggestion))
                } else {
                    completionHandler(nil)
                }

                NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)

                self.uploadPumpEventsIfNeeded(for: pumpID, from: persistenceController.managedObjectContext)
            }
        }
    }

    public func deletePumpEvent(_ event: PersistedPumpEvent, completionHandler: @escaping (_ error: DoseStoreError?) -> Void) {
        guard let context = persistenceController?.managedObjectContext else {
            completionHandler(.configurationError)
            return
        }

        context.perform {
            if let object = event as? NSManagedObject {
                context.delete(object)
            }

            // Reset the latest query date to the newest PumpEvent
            if let pumpID = self.pumpID, let lastEvent = PumpEvent.singleObjectInContext(context,
                    predicate: NSPredicate(format: "pumpID = %@", pumpID),
                    sortedBy: "date",
                    ascending: false
            ) {
                self.pumpEventQueryAfterDate = lastEvent.date
            } else {
                self.pumpEventQueryAfterDate = self.recentValuesStartDate ?? .distantPast
            }

            self.clearPumpEventNormalizedDoseCache()
            completionHandler(nil)

            NotificationCenter.default.post(name: .DoseStoreValuesDidChange, object: self)
        }
    }

    /**
     Whether there's an outstanding upload request to the delegate.
     
     *This method should only be called from within a managed object context block*
     */
    private var isUploadRequestPending = false

    /**
     Asks the delegate to upload all non-uploaded pump events, and updates the store when the delegate calls its completion handler.

     *This method should only be called from within a managed object context block.*
     */
    private func uploadPumpEventsIfNeeded(for pumpID: String, from context: NSManagedObjectContext) {
        guard !isUploadRequestPending, let delegate = delegate else {
            return
        }

        let predicate = NSPredicate(format: "pumpID = %@ && uploaded = false", pumpID)
        guard let objects = try? PumpEvent.objectsInContext(context, predicate: predicate, sortedBy: "date", ascending: true), objects.count > 0 else {
            return
        }

        isUploadRequestPending = true

        let events = objects.map { $0 as PersistedPumpEvent }

        delegate.doseStore(self, hasEventsNeedingUpload: events, fromPumpID: pumpID) { (uploadedObjects) in
            context.perform {
                for id in uploadedObjects {
                    guard let object = try? context.existingObject(with: id), let event = object as? PumpEvent else {
                        continue
                    }

                    event.uploaded = true
                }

                do {
                    try context.save()

                    try self.purgePumpEventObjects()
                } catch {
                }

                self.isUploadRequestPending = false
            }
        }
    }

    /**
     Fetches recent pump events

     - parameter resultsHandler: A closure called when the results are ready. This closure takes two arguments:
        - values: An array of pump event tuples in reverse-chronological order:
            - title:      A human-readable title describing the event
            - dose:       The insulin dose described by the event, if applicable
            - isUploaded: Whether the event has been successfully uploaded by the delegate
        - error:  An error object explaining why the results could not be fetched
     */
    public func getRecentPumpEventValues(_ resultsHandler: @escaping (_ values: [(title: String?, event: PersistedPumpEvent, isUploaded: Bool)], _ error: DoseStoreError?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler([], .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            do {
                let objects = try self.getRecentPumpEventObjects()

                resultsHandler(objects.map({ (title: $0.title, event: $0, isUploaded: $0.uploaded) }), nil)
            } catch let error as DoseStoreError {
                resultsHandler([], error)
            } catch {
                assertionFailure()
            }
        }
    }

    /**
     *This method should only be called from within a managed object context block.*

     - throws: An error describing the failure to fetch objects

     - returns: An array of recently saved reservoir managed objects, in reverse-chronological order
     */
    private func getRecentPumpEventObjects() throws -> [PumpEvent] {
        do {
            return try PumpEvent.objectsInContext(persistenceController!.managedObjectContext, predicate: self.recentValuesPredicate, sortedBy: "date", ascending: false)
        } catch let fetchError as NSError {
            throw DoseStoreError.fetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
        }
    }

    /**
     Retrieves recent dose values derived from pump events.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:      The earliest date of entries to retrieve. The default, and earliest supported value, is the earlier of the current date less `insulinActionDuration` or the previous midnight in the current time zone.
     - parameter endDate:        The latest date of entries to retrieve. Defaults to the distant future.
     - parameter resultsHandler: A closure called once the entries have been retrieved. The closure takes two arguments:
        - doses: The retrieved entries
        - error: An error object explaining why the retrieval failed
     */
    func getRecentNormalizedPumpEventDoseEntries(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ doses: [DoseEntry], _ error: DoseStoreError?) -> Void) {
        guard let persistenceController = persistenceController, let basalProfile = basalProfile else {
            resultsHandler([], .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            if let normalizedDoses = self.recentPumpEventNormalizedDoseEntriesCache {
                resultsHandler(normalizedDoses.filterDateRange(startDate, endDate), nil)
            } else {
                do {
                    let doses = try self.getRecentPumpEventObjects().flatMap { $0.dose }.reversed()
                    let reconciledDoses = InsulinMath.reconcileDoses(doses + (self.mutablePumpEventDoses ?? []))
                    let normalizedDoses = InsulinMath.normalize(reconciledDoses, againstBasalSchedule: basalProfile)

                    self.recentPumpEventNormalizedDoseEntriesCache = normalizedDoses
                    resultsHandler(normalizedDoses.filterDateRange(startDate, endDate), nil)
                } catch let error as DoseStoreError {
                    resultsHandler([], error)
                } catch {
                    assertionFailure()
                }
            }
        }
    }


    /**
     Removes uploaded pump event objects older than the recency predicate

     *This method should only be called from within a managed object context block.*

     - throws: A core data exception if the delete request failed
     */
    private func purgePumpEventObjects() throws {
        let uploadedPredicate = NSPredicate(format: "uploaded = true")

        guard let datePredicate = purgeableValuesPredicate, let persistenceController = persistenceController else {
            throw DoseStoreError.configurationError
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, uploadedPredicate])

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: PumpEvent.entityName())
        fetchRequest.predicate = predicate

        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        deleteRequest.resultType = .resultTypeCount

        if let result = try persistenceController.managedObjectContext.execute(deleteRequest) as? NSBatchDeleteResult, let count = result.result as? Int, count > 0 {
            persistenceController.managedObjectContext.refreshAllObjects()
        }
    }

    // MARK: - Math

    /**
     *This method should only be called from within a managed object context block.*
     */
    private func clearReservoirCache() {
        clearReservoirDoseCache()
    }

    /**
     *This method should only be called from within a managed object context block.*
     */
    private func clearReservoirDoseCache() {
        recentReservoirDoseEntriesCache = nil

        clearReservoirNormalizedDoseCache()
    }

    /**
     *This method should only be called from within a managed object context block.*
     */
    private func clearReservoirNormalizedDoseCache() {
        recentReservoirNormalizedDoseEntriesCache = nil

        clearCalculationCache()
    }

    /**
     *This method should only be called from within a managed object context block.*
     */
    private func clearPumpEventNormalizedDoseCache() {
        recentPumpEventNormalizedDoseEntriesCache = nil

        clearCalculationCache()
    }

    /**
     *This method should only be called from within a managed object context block.*
     */
    private func clearCalculationCache() {
        self.insulinOnBoardCache = nil
        self.glucoseEffectsCache = nil
    }

    private var insulinOnBoardCache: [InsulinValue]?

    private var glucoseEffectsCache: [GlucoseEffect]?

    /**
     Retrieves recent dose values derived from either pump events or reservoir readings.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:      The earliest date of entries to retrieve. The default, and earliest supported value, is the earlier of the current date less `insulinActionDuration` or the previous midnight in the current time zone.
     - parameter endDate:        The latest date of entries to retrieve. Defaults to the distant future.
     - parameter resultsHandler: A closure called once the entries have been retrieved. The closure takes two arguments:
        - doses: The retrieved entries
        - error: An error object explaining why the retrieval failed
     */
    public func getRecentNormalizedDoseEntries(startDate: Date? = nil, endDate: Date? = nil, resultsHandler: @escaping (_ doses: [DoseEntry], _ error: DoseStoreError?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler([], .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            if self.areReservoirValuesContinuous && self.lastAddedPumpEvents.timeIntervalSinceNow < -TimeInterval(minutes: 20) {
                self.getRecentNormalizedReservoirDoseEntries(startDate: startDate, endDate: endDate, resultsHandler: resultsHandler)
            } else {
                self.getRecentNormalizedPumpEventDoseEntries(startDate: startDate, endDate: endDate, resultsHandler: resultsHandler)
            }
        }
    }

    /**
     Retrieves the most recent unabsorbed insulin value relative to the specified date
     
     - parameter date:          The date of the value to retrieve.
     - parameter resultHandler: A closure called once the value has been retrieved. The closure takes two arguemnts:
        - value: The retrieved value
        - error: An error object explaining why the retrieval failed
     */
    public func insulinOnBoardAtDate(_ date: Date, resultHandler: @escaping (_ value: InsulinValue?, _ error: Error?) -> Void) {
        getInsulinOnBoardValues { (values, error) -> Void in
            resultHandler(values.closestPriorToDate(date), error)
        }
    }

    /**
     Retrieves a timeline of unabsorbed insulin values.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:     The earliest date of values to retrieve. The default, and earliest supported value, is the previous midnight in the current time zone.
     - parameter endDate:       The latest date of values to retrieve. Defaults to the distant future.
     - parameter resultHandler: A closure called once the values have been retrieved. The closure takes two arguments:
        - values: The retrieved values
        - error:  An error object explaining why the retrieval failed
     */
    public func getInsulinOnBoardValues(startDate: Date? = nil, endDate: Date? = nil, resultHandler: @escaping (_ values: [InsulinValue], _ error: DoseStoreError?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultHandler([], .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            if self.insulinOnBoardCache == nil {
                if let insulinActionDuration = self.insulinActionDuration {
                    if self.areReservoirValuesContinuous {
                        self.getRecentNormalizedReservoirDoseEntries { (doses, error) -> Void in
                            if error == nil {
                                self.insulinOnBoardCache = InsulinMath.insulinOnBoardForDoses(doses, actionDuration: insulinActionDuration)
                            }

                            resultHandler(self.insulinOnBoardCache?.filterDateRange(startDate, endDate) ?? [], error)
                        }
                    } else {
                        self.getRecentNormalizedPumpEventDoseEntries { (doses, error) in
                            if error == nil {
                                self.insulinOnBoardCache = InsulinMath.insulinOnBoardForDoses(doses, actionDuration: insulinActionDuration)
                            }

                            resultHandler(self.insulinOnBoardCache?.filterDateRange(startDate, endDate) ?? [], error)
                        }
                    }
                } else {
                    resultHandler([], .configurationError)
                }
            } else {
                resultHandler(self.insulinOnBoardCache?.filterDateRange(startDate, endDate) ?? [], nil)
            }
        }
    }

    /**
     Retrieves a timeline of effect on blood glucose from doses

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:     The earliest date of effects to retrieve. The default, and earliest supported value, is the previous midnight in the current time zone.
     - parameter endDate:       The latest date of effects to retrieve. Defaults to the distant future.
     - parameter resultHandler: A closure called once the effects have been retrieved. The closure takes two arguments:
        - effects: The retrieved timeline of effects
        - error:   An error object explaining why the retrieval failed
     */
    public func getGlucoseEffects(startDate: Date? = nil, endDate: Date? = nil, resultHandler: @escaping (_ effects: [GlucoseEffect], _ error: DoseStoreError?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultHandler([], .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            if self.glucoseEffectsCache == nil {
                if let insulinActionDuration = self.insulinActionDuration, let insulinSensitivitySchedule = self.insulinSensitivitySchedule {
                    if self.areReservoirValuesContinuous {
                        self.getRecentNormalizedReservoirDoseEntries { (doses, error) -> Void in
                            if error == nil {
                                self.glucoseEffectsCache = InsulinMath.glucoseEffectsForDoses(doses, actionDuration: insulinActionDuration, insulinSensitivity: insulinSensitivitySchedule)
                            }

                            resultHandler(self.glucoseEffectsCache?.filterDateRange(startDate, endDate) ?? [], error)
                        }
                    } else {
                        self.getRecentNormalizedPumpEventDoseEntries { (doses, error) -> Void in
                            if error == nil {
                                self.glucoseEffectsCache = InsulinMath.glucoseEffectsForDoses(doses, actionDuration: insulinActionDuration, insulinSensitivity: insulinSensitivitySchedule)
                            }

                            resultHandler(self.glucoseEffectsCache?.filterDateRange(startDate, endDate) ?? [], error)
                        }
                    }
                } else {
                    resultHandler([], .configurationError)
                }
            } else {
                resultHandler(self.glucoseEffectsCache?.filterDateRange(startDate, endDate) ?? [], nil)
            }
        }
    }

    /**
     Retrieves the total number of units delivered for a default time period: the earlier of the current date less `insulinActionDuration` or the previous midnight in the current time zone, and the distant future.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter resultsHandler: A closure called once the total has been retrieved. The closure takes two arguments:
        - total: The retrieved value
        - since: The earliest date included in the total
        - error: An error object explaining why the retrieval failed
     */
    public func getTotalRecentUnitsDelivered(_ resultsHandler: @escaping (_ total: Double, _ since: Date?, _ error: DoseStoreError?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler(0, nil, .configurationError)
            return
        }

        persistenceController.managedObjectContext.perform {
            do {
                let doses = try self.getRecentReservoirDoseEntries()

                resultsHandler(InsulinMath.totalDeliveryForDoses(doses), doses.first?.startDate, nil)
            } catch let error as DoseStoreError {
                resultsHandler(0, nil, error)
            } catch {
                assertionFailure()
            }
        }
    }

    /// Generates a diagnostic report about the current state
    ///
    /// This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.
    ///
    /// - parameter completionHandler: The closure takes a single argument of the report string.
    public func generateDiagnosticReport(_ completionHandler: @escaping (_ report: String) -> Void) {
        var report: [String] = [
            "## DoseStore",
            "",
            "* readyState: \(readyState)",
            "* insulinActionDuration: \(insulinActionDuration ?? 0)",
            "* basalProfile: \(basalProfile?.debugDescription ?? "")",
            "* insulinSensitivitySchedule: \(insulinSensitivitySchedule?.debugDescription ?? "")",
            "* areReservoirValuesContinuous: \(areReservoirValuesContinuous)"
        ]

        getRecentReservoirValues { (values, error) in
            report.append("")
            report.append("### getRecentReservoirValues")

            if let error = error {
                report.append("Error: \(error)")
            } else {
                report.append("")
                for value in values {
                    report.append("* \(value.startDate), \(value.unitVolume)")
                }
            }

            self.getRecentPumpEventValues { (values, error) in
                report.append("")
                report.append("### getRecentPumpEventValues")

                if let error = error {
                    report.append("Error: \(error)")
                } else {
                    report.append("")
                    for value in values {
                        report.append("* \(value)")
                    }
                }

                self.getRecentNormalizedDoseEntries { (entries, error) in
                    report.append("")
                    report.append("### getRecentNormalizedDoseEntries")

                    if let error = error {
                        report.append("Error: \(error)")
                    } else {
                        report.append("")
                        for entry in entries {
                            report.append("* \(entry)")
                        }
                    }

                    completionHandler(report.joined(separator: "\n"))
                }
            }
        }
    }
}
