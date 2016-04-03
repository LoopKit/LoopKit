//
//  DoseStore.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/27/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import CoreData
import LoopKit


public protocol ReservoirValue {
    var startDate: NSDate { get }
    var unitVolume: Double { get }
}


public class DoseStore {

    /// Notification posted when the ready state was modified.
    public static let ReadyStateDidChangeNotification = "com.loudnate.InsulinKit.ReadyStateDidUpdateNotification"

    /// Notification posted when reservoir data was modifed.
    public static let ReservoirValuesDidChangeNotification = "com.loudnate.InsulinKit.ReservoirValuesDidChangeNotification"

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
            persistenceController?.managedObjectContext.performBlock {
                self.clearReservoirCache()
            }
            configurationDidChange()
        }
    }

    public var insulinActionDuration: NSTimeInterval? {
        didSet {
            persistenceController?.managedObjectContext.performBlock {
                self.clearCalculationCache()
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
                }
            })
        } else {
            readyState = .Ready
        }
    }

    private var persistenceController: PersistenceController?

    // MARK: - Reservoir data

    private var recentReservoirObjectsCache: [Reservoir]?

    private var recentReservoirNormalizedDoseEntriesCache: [DoseEntry]?

    private var recentReservoirDoseEntriesCache: [DoseEntry]?

    private var recentReservoirValuesStartDate: NSDate? {
        if let insulinActionDuration = insulinActionDuration {
            let calendar = NSCalendar.currentCalendar()

            return min(calendar.startOfDayForDate(NSDate()), NSDate(timeIntervalSinceNow: -insulinActionDuration - NSTimeInterval(minutes: 5)))
        } else {
            return nil
        }
    }

    private var recentReservoirValuesPredicate: NSPredicate? {
        if let pumpID = pumpID, startDate = recentReservoirValuesStartDate {
            let predicate = NSPredicate(format: "date >= %@ && pumpID = %@", startDate, pumpID)

            return predicate
        } else {
            return nil
        }
    }

    public func addReservoirValue(unitVolume: Double, atDate date: NSDate, completionHandler: (value: ReservoirValue?, error: Error?) -> Void) {

        if let pumpID = pumpID, persistenceController = persistenceController {
            persistenceController.managedObjectContext.performBlock {
                let reservoir = Reservoir.insertNewObjectInContext(persistenceController.managedObjectContext)

                reservoir.volume = unitVolume
                reservoir.date = date
                reservoir.pumpID = pumpID

                if self.recentReservoirObjectsCache != nil, let predicate = self.recentReservoirValuesPredicate {
                    self.recentReservoirObjectsCache = self.recentReservoirObjectsCache!.filter { predicate.evaluateWithObject($0) }

                    if self.recentReservoirDoseEntriesCache != nil, let
                        basalProfile = self.basalProfile,
                        minEndDate = self.recentReservoirValuesStartDate
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
                        completionHandler(value: reservoir, error: .PersistenceError(description: error.description, recoverySuggestion: error.recoverySuggestion))
                    } else {
                        completionHandler(value: reservoir, error: nil)
                    }

                    NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.ReservoirValuesDidChangeNotification, object: self)
                }
            }
        } else {
            completionHandler(value: nil, error: .ConfigurationError)
        }
    }

    /**
     Fetches recent reservoir values

     - parameter resultsHandler: A closure called when the results are ready. This closure takes two arguments:
        - objects: An array of reservoir objects in reverse-chronological order
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
        } else {
            do {
                try self.purgeReservoirObjects()

                var recentReservoirObjects: [Reservoir] = []

                recentReservoirObjects += try Reservoir.objectsInContext(persistenceController!.managedObjectContext, predicate: self.recentReservoirValuesPredicate, sortedBy: "date", ascending: false)

                self.recentReservoirObjectsCache = recentReservoirObjects

                return recentReservoirObjects
            } catch let fetchError as NSError {
                throw Error.FetchError(description: fetchError.localizedDescription, recoverySuggestion: fetchError.localizedRecoverySuggestion)
            }
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

                NSNotificationCenter.defaultCenter().postNotificationName(self.dynamicType.ReservoirValuesDidChangeNotification, object: self)
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
        if let subPredicate = recentReservoirValuesPredicate, persistenceController = persistenceController {
            let predicate = NSCompoundPredicate(notPredicateWithSubpredicate: subPredicate)
            let fetchRequest = Reservoir.fetchRequest(persistenceController.managedObjectContext, predicate: predicate)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            deleteRequest.resultType = .ResultTypeCount

            if let result = try persistenceController.managedObjectContext.executeRequest(deleteRequest) as? NSBatchDeleteResult, count = result.result as? Int where count > 0 {
                recentReservoirObjectsCache?.removeAll()
                persistenceController.managedObjectContext.reset()
            }
        } else {
            throw Error.ConfigurationError
        }
    }

    // MARK: Math

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
            resultHandler(value: values.closestToDate(date), error: error)
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
        - error: An error object explaining why the retrieval failed
     */
    public func getTotalRecentUnitsDelivered(resultsHandler: (total: Double, error: Error?) -> Void) {
        guard let persistenceController = persistenceController else {
            resultsHandler(total: 0, error: .ConfigurationError)
            return
        }

        persistenceController.managedObjectContext.performBlock {
            do {
                let doses = try self.getRecentReservoirDoseEntries()

                resultsHandler(total: InsulinMath.totalDeliveryForDoses(doses), error: nil)
            } catch let error as Error {
                resultsHandler(total: 0, error: error)
            } catch {
                assertionFailure()
            }
        }
    }
}
