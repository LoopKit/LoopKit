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
    func doseStore(doseStore: DoseStore, hasEventsNeedingUpload pumpEvents: [PersistedPumpEvent], fromPumpID pumpID: String, withCompletion completionHandler: (uploadedObjects: [NSManagedObjectID]) -> Void)
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
 */
public final class DoseStore {

    /// Notification posted when the ready state was modified.
    public static let ReadyStateDidChangeNotification = "com.loudnate.InsulinKit.ReadyStateDidUpdateNotification"

    /// Notification posted when data was modifed.
    public static let ValuesDidChangeNotification = "com.loudnate.InsulinKit.ValuesDidChangeNotification"

    public enum ReadyState {
        case NeedsConfiguration
        case Initializing
        case Ready
        case Failed(Error)
    }

    public var readyState = ReadyState.NeedsConfiguration {
        didSet {
            NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.ReadyStateDidChangeNotification, object: self)
        }
    }

    public enum Error: ErrorType {
        case ConfigurationError
        case InitializationError(description: String, recoverySuggestion: String)
        case PersistenceError(description: String, recoverySuggestion: String?)
        case FetchError(description: String, recoverySuggestion: String?)
    }

    public var pumpID: String? {
        didSet {
            guard pumpID != oldValue else {
                return
            }

            persistenceController?.managedObjectContext.performBlock {
                self.clearReservoirCache()
                self.pumpEventQueryAfterDate = self.recentValuesStartDate ?? NSDate.distantPast()
            }
            configurationDidChange()
        }
    }

    public weak var delegate: DoseStoreDelegate? {
        didSet {
            isUploadRequestPending = false
        }
    }

    public var insulinActionDuration: NSTimeInterval? {
        didSet {
            persistenceController?.managedObjectContext.performBlock {
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
            persistenceController?.managedObjectContext.performBlock {
                self.clearReservoirDoseCache()
            }
        }
    }

    public var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        didSet {
            persistenceController?.managedObjectContext.performBlock {
                self.clearReservoirDoseCache()
            }
        }
    }

    public init(pumpID: String?, insulinActionDuration: NSTimeInterval?, basalProfile: BasalRateSchedule?, insulinSensitivitySchedule: InsulinSensitivitySchedule?) {
        self.pumpID = pumpID
        self.insulinActionDuration = insulinActionDuration
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
        self.basalProfile = basalProfile
        self.pumpEventQueryAfterDate = recentValuesStartDate ?? NSDate.distantPast()

        configurationDidChange()
    }

    private func configurationDidChange() {
        if insulinActionDuration != nil && pumpID != nil {
            initializePersistenceController()
        } else {
            readyState = .NeedsConfiguration
        }
    }

    private func initializePersistenceController() {
        if persistenceController == nil, case .NeedsConfiguration = readyState {
            readyState = .Initializing

            persistenceController = PersistenceController(readyCallback: { [unowned self] (error) -> Void in
                if let error = error {
                    self.readyState = .Failed(.InitializationError(description: error.description, recoverySuggestion: error.recoverySuggestion))
                } else {
                    self.readyState = .Ready

                    if let context = self.persistenceController?.managedObjectContext, pumpID = self.pumpID {
                        // Find the newest PumpEvent date we have
                        if let lastEvent = PumpEvent.singleObjectInContext(context,
                            predicate: NSPredicate(format: "pumpID = %@", pumpID),
                            sortedBy: "date",
                            ascending: false
                        ) {
                            self.pumpEventQueryAfterDate = lastEvent.date
                        }
                    }
                }
            })
        } else {
            readyState = .Ready
        }
    }

    private var persistenceController: PersistenceController?

    private var recentValuesPredicate: NSPredicate? {
        if let pumpID = pumpID, startDate = recentValuesStartDate {
            let predicate = NSPredicate(format: "date >= %@ && pumpID = %@", startDate, pumpID)

            return predicate
        } else {
            return nil
        }
    }

    private var purgeableValuesPredicate: NSPredicate? {
        if let pumpID = pumpID, startDate = recentValuesStartDate {
            let predicate = NSPredicate(format: "date < %@", startDate, pumpID)

            return predicate
        } else {
            return nil
        }
    }

    // MARK: - Reservoir data

    private var recentReservoirObjectsCache: [Reservoir]?

    private var recentReservoirNormalizedDoseEntriesCache: [DoseEntry]?

    private var recentReservoirDoseEntriesCache: [DoseEntry]?

    private var recentValuesStartDate: NSDate? {
        if let insulinActionDuration = insulinActionDuration {
            let calendar = NSCalendar.currentCalendar()

            return min(calendar.startOfDayForDate(NSDate()), NSDate(timeIntervalSinceNow: -insulinActionDuration * 3 / 2 - NSTimeInterval(minutes: 5)))
        } else {
            return nil
        }
    }

    /**
     Adds and persists a new reservoir value

     - parameter unitVolume:        The reservoir volume, in units
     - parameter date:              The date of the volume reading
     - parameter completionHandler: A closure called after the value was saved. This closure takes three arguments:
        - value:         The new reservoir value, if it was saved
        - previousValue: The last new reservoir value
        - error:         An error object explaining why the value could not be saved
     */
    public func addReservoirValue(unitVolume: Double, atDate date: NSDate, completionHandler: (value: ReservoirValue?, previousValue: ReservoirValue?, error: Error?) -> Void) {
        guard let pumpID = pumpID, persistenceController = persistenceController else {
            completionHandler(value: nil, previousValue: nil, error: .ConfigurationError)
            return
        }

        persistenceController.managedObjectContext.performBlock {
            let reservoir = Reservoir.insertNewObjectInContext(persistenceController.managedObjectContext)

            reservoir.volume = unitVolume
            reservoir.date = date
            reservoir.pumpID = pumpID

            let previousValue = self.recentReservoirObjectsCache?.first

            if self.recentReservoirObjectsCache != nil, let predicate = self.recentValuesPredicate {
                self.recentReservoirObjectsCache = self.recentReservoirObjectsCache!.filter { predicate.evaluateWithObject($0) }

                if self.recentReservoirDoseEntriesCache != nil, let
                    basalProfile = self.basalProfile,
                    minEndDate = self.recentValuesStartDate
                {
                    self.recentReservoirDoseEntriesCache = self.recentReservoirDoseEntriesCache!.filter { $0.endDate >= minEndDate }

                    var newValues: [Reservoir] = []

                    if let previousValue = self.recentReservoirObjectsCache?.first {
                        newValues.append(previousValue)
                    }

                    newValues.append(reservoir)

                    let newDoseEntries = InsulinMath.doseEntriesFromReservoirValues(newValues)

                    self.recentReservoirDoseEntriesCache! += newDoseEntries

                    if self.recentReservoirNormalizedDoseEntriesCache != nil {
                        self.recentReservoirNormalizedDoseEntriesCache = self.recentReservoirNormalizedDoseEntriesCache!.filter { $0.endDate > minEndDate }

                        self.recentReservoirNormalizedDoseEntriesCache! += InsulinMath.normalize(newDoseEntries, againstBasalSchedule: basalProfile)
                    }
                }

                self.recentReservoirObjectsCache!.insert(reservoir, atIndex: 0)
            }

            self.clearCalculationCache()

            persistenceController.save { (error) -> Void in
                if let error = error {
                    completionHandler(value: reservoir, previousValue: previousValue, error: .PersistenceError(description: error.description, recoverySuggestion: error.recoverySuggestion))
                } else {
                    completionHandler(value: reservoir, previousValue: previousValue, error: nil)
                }

                NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.ValuesDidChangeNotification, object: self)
            }
        }
    }

    /**
     Fetches recent reservoir values

     - parameter resultsHandler: A closure called when the results are ready. This closure takes two arguments:
        - objects: An array of reservoir values in reverse-chronological order
        - error:   An error object explaining why the results could not be fetched
     */
    public func getRecentReservoirValues(resultsHandler: (values: [ReservoirValue], error: Error?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler(values: [], error: .ConfigurationError)
            return
        }

        persistenceController.managedObjectContext.performBlock {
            do {
                let objects = try self.getRecentReservoirObjects()

                resultsHandler(values: objects.map({ $0 as ReservoirValue}), error: nil)
            } catch let error as Error {
                resultsHandler(values: [], error: error)
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
        if let objects = recentReservoirObjectsCache {
            return objects
        }

        do {
            try self.purgeReservoirObjects()

            var recentReservoirObjects: [Reservoir] = []

            recentReservoirObjects += try Reservoir.objectsInContext(persistenceController!.managedObjectContext, predicate: self.recentValuesPredicate, sortedBy: "date", ascending: false)

            self.recentReservoirObjectsCache = recentReservoirObjects

            return recentReservoirObjects
        } catch let fetchError as NSError {
            throw Error.FetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
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

            self.recentReservoirDoseEntriesCache = InsulinMath.doseEntriesFromReservoirValues(objects.reverse())
            return self.recentReservoirDoseEntriesCache ?? []
        }
    }

    /**
     Retrieves recent dose values.

     This operation is performed asynchronously and the completion will be executed on an arbitrary background queue.

     - parameter startDate:      The earliest date of entries to retrieve. The default, and earliest supported value, is the earlier of the current date less `insulinActionDuration` or the previous midnight in the current time zone.
     - parameter endDate:        The latest date of entries to retrieve. Defaults to the distant future.
     - parameter resultsHandler: A closure called once the entries have been retrieved. The closure takes two arguments:
        - doses: The retrieved entries
        - error: An error object explaining why the retrieval failed
     */
    public func getRecentNormalizedReservoirDoseEntries(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultsHandler: (doses: [DoseEntry], error: Error?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler(doses: [], error: .ConfigurationError)
            return
        }

        persistenceController.managedObjectContext.performBlock {
            if let normalizedDoses = self.recentReservoirNormalizedDoseEntriesCache {
                resultsHandler(doses: normalizedDoses.filterDateRange(startDate, endDate), error: nil)
            } else {
                if let basalProfile = self.basalProfile {
                    do {
                        let doses = try self.getRecentReservoirDoseEntries()

                        let normalizedDoses = InsulinMath.normalize(doses, againstBasalSchedule: basalProfile)
                        self.recentReservoirNormalizedDoseEntriesCache = normalizedDoses
                        resultsHandler(doses: normalizedDoses.filterDateRange(startDate, endDate) ?? [], error: nil)
                    } catch let error as Error {
                        resultsHandler(doses: [], error: error)
                    } catch {
                        assertionFailure()
                    }
                } else {
                    resultsHandler(doses: [], error: .ConfigurationError)
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
    public func deleteReservoirValue(value: ReservoirValue, completionHandler: (deletedValues: [ReservoirValue], error: Error?) -> Void) {

        if let persistenceController = persistenceController {
            persistenceController.managedObjectContext.performBlock {
                var deletedObjects = [Reservoir]()
                var error: Error?

                if let object = value as? Reservoir {
                    self.deleteReservoirObject(object)
                    deletedObjects.append(object)
                } else if let pumpID = self.pumpID {
                    // TODO: Unecessary case handling?
                    let predicate = NSPredicate(format: "date = %@ && pumpID = %@", value.startDate, pumpID)

                    do {
                        for object in try Reservoir.objectsInContext(persistenceController.managedObjectContext, predicate: predicate) {
                            self.deleteReservoirObject(object)
                            deletedObjects.append(object)
                        }
                    } catch let deleteError as NSError {
                        error = .PersistenceError(description: deleteError.localizedDescription, recoverySuggestion: deleteError.localizedRecoverySuggestion)
                    }
                }

                self.clearReservoirDoseCache()

                completionHandler(deletedValues: deletedObjects.map { $0 }, error: error)

                NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.ValuesDidChangeNotification, object: self)
            }
        } else {
            completionHandler(deletedValues: [], error: .ConfigurationError)
        }
    }

    /**
     Deletes a specified reservoir object from the context and removes it from the cache

     *This method should only be called from within a managed object context block.*

     - parameter object: The object to delete
     */
    private func deleteReservoirObject(object: Reservoir) {
        persistenceController?.managedObjectContext.deleteObject(object)

        if let index = recentReservoirObjectsCache?.indexOf(object) {
            recentReservoirObjectsCache?.removeAtIndex(index)
        }
    }

    /**
     Removes reservoir objects older than the recency predicate

     *This method should only be called from within a managed object context block.*

     - throws: A core data exception if the delete request failed
     */
    private func purgeReservoirObjects() throws {
        guard let predicate = purgeableValuesPredicate, persistenceController = persistenceController else {
            throw Error.ConfigurationError
        }

        let fetchRequest = Reservoir.fetchRequest(persistenceController.managedObjectContext, predicate: predicate)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        deleteRequest.resultType = .ResultTypeCount

        if let result = try persistenceController.managedObjectContext.executeRequest(deleteRequest) as? NSBatchDeleteResult, count = result.result as? Int where count > 0 {
            recentReservoirObjectsCache?.removeAll()
            persistenceController.managedObjectContext.refreshAllObjects()
        }
    }

    // MARK: - Pump Event History

    /// The earliest event date that should included in subsequent queries for pump event data.
    public private(set) var pumpEventQueryAfterDate = NSDate.distantPast()

    /// The last-seen mutable pump events, which aren't persisted but are used for dose calculation.
    private var mutablePumpEventDoses: [DoseEntry]?

    /**
     Adds and persists new pump events.
     
     Events are deduplicated by a unique constraint of pump ID, date, and raw data.

     - parameter events:            An array of new pump events
     - parameter completionHandler: A closure called after the events are saved. The closure takes a single argument:
        - error: An error object explaining why the events could not be saved.
     */
    public func addPumpEvents(events: [NewPumpEvent], completionHandler: (error: Error?) -> Void) {
        guard let pumpID = pumpID, persistenceController = persistenceController else {
            completionHandler(error: .ConfigurationError)
            return
        }

        guard events.count > 0 else {
            completionHandler(error: nil)
            return
        }

        persistenceController.managedObjectContext.performBlock {
            var lastFinalDate: NSDate?
            var firstMutableDate: NSDate?

            var mutablePumpEventDoses: [DoseEntry] = []

            for event in events {
                if event.isMutable {
                    firstMutableDate = min(event.date, firstMutableDate ?? event.date)

                    if let dose = event.dose {
                        mutablePumpEventDoses.append(dose)
                    }
                } else {
                    lastFinalDate = max(event.date, lastFinalDate ?? event.date)

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

            persistenceController.save { (error) -> Void in
                if let error = error {
                    completionHandler(error: .PersistenceError(description: error.description, recoverySuggestion: error.recoverySuggestion))
                } else {
                    completionHandler(error: nil)
                }

                NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.ValuesDidChangeNotification, object: self)

                self.uploadPumpEventsIfNeeded(for: pumpID, from: persistenceController.managedObjectContext)
            }
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
        guard let objects = try? PumpEvent.objectsInContext(context, predicate: predicate, sortedBy: "date", ascending: false) where objects.count > 0 else {
            return
        }

        isUploadRequestPending = true

        let events = objects.map { $0 as PersistedPumpEvent }

        delegate.doseStore(self, hasEventsNeedingUpload: events, fromPumpID: pumpID) { (uploadedObjects) in
            context.performBlock {
                for id in uploadedObjects {
                    guard let object = try? context.existingObjectWithID(id), event = object as? PumpEvent else {
                        continue
                    }

                    event.uploaded = true
                }

                do {
                    try context.save()

                    try self.purgePumpEventObjects()
                } catch _ as NSError {
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
    public func getRecentPumpEventValues(resultsHandler: (values: [(title: String?, event: PersistedPumpEvent, isUploaded: Bool)], error: Error?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler(values: [], error: .ConfigurationError)
            return
        }

        persistenceController.managedObjectContext.performBlock {
            do {
                let objects = try self.getRecentPumpEventObjects()

                resultsHandler(values: objects.map({ (title: $0.title, event: $0, isUploaded: $0.uploaded) }), error: nil)
            } catch let error as Error {
                resultsHandler(values: [], error: error)
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
            throw Error.FetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
        }
    }

    /**
     Removes uploaded pump event objects older than the recency predicate

     *This method should only be called from within a managed object context block.*

     - throws: A core data exception if the delete request failed
     */
    private func purgePumpEventObjects() throws {
        let uploadedPredicate = NSPredicate(format: "uploaded = true")

        guard let datePredicate = purgeableValuesPredicate, persistenceController = persistenceController else {
            throw Error.ConfigurationError
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, uploadedPredicate])
        let fetchRequest = PumpEvent.fetchRequest(persistenceController.managedObjectContext, predicate: predicate)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        deleteRequest.resultType = .ResultTypeCount

        if let result = try persistenceController.managedObjectContext.executeRequest(deleteRequest) as? NSBatchDeleteResult, count = result.result as? Int where count > 0 {
            persistenceController.managedObjectContext.refreshAllObjects()
        }
    }

    // MARK: - Math

    /**
     *This method should only be called from within a managed object context block.*
     */
    private func clearReservoirCache() {
        recentReservoirObjectsCache = nil

        clearReservoirDoseCache()
    }

    /**
     *This method should only be called from within a managed object context block.*
     */
    private func clearReservoirDoseCache() {
        recentReservoirDoseEntriesCache = nil
        recentReservoirNormalizedDoseEntriesCache = nil

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
     TODO: Calculate IOB to the exact provided date.
     */
    public func insulinOnBoardAtDate(date: NSDate, resultHandler: (value: InsulinValue?, error: Error?) -> Void) {
        getInsulinOnBoardValues { (values, error) -> Void in
            resultHandler(value: values.closestPriorToDate(date), error: error)
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
    public func getInsulinOnBoardValues(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultHandler: (values: [InsulinValue], error: Error?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultHandler(values: [], error: .ConfigurationError)
            return
        }

        persistenceController.managedObjectContext.performBlock {
            if self.insulinOnBoardCache == nil {
                if let insulinActionDuration = self.insulinActionDuration {
                    self.getRecentNormalizedReservoirDoseEntries { (doses, error) -> Void in
                        if error == nil {
                            self.insulinOnBoardCache = InsulinMath.insulinOnBoardForDoses(doses, actionDuration: insulinActionDuration)
                        }

                        resultHandler(values: self.insulinOnBoardCache?.filterDateRange(startDate, endDate) ?? [], error: error)
                    }
                } else {
                    resultHandler(values: [], error: .ConfigurationError)
                }
            } else {
                resultHandler(values: self.insulinOnBoardCache?.filterDateRange(startDate, endDate) ?? [], error: nil)
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
    public func getGlucoseEffects(startDate startDate: NSDate? = nil, endDate: NSDate? = nil, resultHandler: (effects: [GlucoseEffect], error: Error?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultHandler(effects: [], error: .ConfigurationError)
            return
        }

        persistenceController.managedObjectContext.performBlock {
            if self.glucoseEffectsCache == nil {
                if let insulinActionDuration = self.insulinActionDuration, insulinSensitivitySchedule = self.insulinSensitivitySchedule {
                    self.getRecentNormalizedReservoirDoseEntries { (doses, error) -> Void in
                        if error == nil {
                            self.glucoseEffectsCache = InsulinMath.glucoseEffectsForDoses(doses, actionDuration: insulinActionDuration, insulinSensitivity: insulinSensitivitySchedule)
                        }

                        resultHandler(effects: self.glucoseEffectsCache?.filterDateRange(startDate, endDate) ?? [], error: error)
                    }
                } else {
                    resultHandler(effects: [], error: .ConfigurationError)
                }
            } else {
                resultHandler(effects: self.glucoseEffectsCache?.filterDateRange(startDate, endDate) ?? [], error: nil)
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
    public func getTotalRecentUnitsDelivered(resultsHandler: (total: Double, since: NSDate?, error: Error?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler(total: 0, since: nil, error: .ConfigurationError)
            return
        }

        persistenceController.managedObjectContext.performBlock {
            do {
                let doses = try self.getRecentReservoirDoseEntries()

                resultsHandler(total: InsulinMath.totalDeliveryForDoses(doses), since: doses.last?.startDate, error: nil)
            } catch let error as Error {
                resultsHandler(total: 0, since: nil, error: error)
            } catch {
                assertionFailure()
            }
        }
    }
}
