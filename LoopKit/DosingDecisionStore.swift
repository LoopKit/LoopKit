//
//  DosingDecisionStore.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import Foundation
import CoreData

public protocol DosingDecisionStoreDelegate: AnyObject {
    /**
     Informs the delegate that the dosing decision store has updated dosing decision data.
     
     - Parameter dosingDecisionStore: The dosing decision store that has updated dosing decision data.
     */
    func dosingDecisionStoreHasUpdatedDosingDecisionData(_ dosingDecisionStore: DosingDecisionStore)
}

public class DosingDecisionStore {
    public weak var delegate: DosingDecisionStoreDelegate?
    
    private let store: PersistenceController
    private let expireAfter: TimeInterval
    private let dataAccessQueue = DispatchQueue(label: "com.loopkit.DosingDecisionStore.dataAccessQueue", qos: .utility)
    public let log = OSLog(category: "DosingDecisionStore")

    public init(store: PersistenceController, expireAfter: TimeInterval) {
        self.store = store
        self.expireAfter = expireAfter
    }

    public func storeDosingDecisionData(_ dosingDecisionData: StoredDosingDecisionData, completion: @escaping () -> Void) {
        dataAccessQueue.async {
            self.store.managedObjectContext.performAndWait {
                let object = DosingDecisionObject(context: self.store.managedObjectContext)
                object.date = dosingDecisionData.date
                object.data = dosingDecisionData.data
                self.store.save()
            }

            self.purgeExpiredDosingDecisions()
            completion()
        }
    }

    public var expireDate: Date {
        return Date(timeIntervalSinceNow: -expireAfter)
    }

    private func purgeExpiredDosingDecisions() {
        purgeDosingDecisionObjects(before: expireDate)
    }

    public func purgeDosingDecisions(before date: Date, completion: @escaping (Error?) -> Void) {
        dataAccessQueue.async {
            self.purgeDosingDecisionObjects(before: date, completion: completion)
        }
    }

    private func purgeDosingDecisionObjects(before date: Date, completion: ((Error?) -> Void)? = nil) {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        var purgeError: Error?

        store.managedObjectContext.performAndWait {
            do {
                let count = try self.store.managedObjectContext.purgeObjects(of: DosingDecisionObject.self, matching: NSPredicate(format: "date < %@", date as NSDate))
                self.log.info("Purged %d DosingDecisionObjects", count)
            } catch let error {
                self.log.error("Unable to purge DosingDecisionObjects: %{public}@", String(describing: error))
                purgeError = error
            }
        }

        if let purgeError = purgeError {
            completion?(purgeError)
            return
        }

        delegate?.dosingDecisionStoreHasUpdatedDosingDecisionData(self)
        completion?(nil)
    }
}

extension DosingDecisionStore {
    public struct QueryAnchor: RawRepresentable {
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
    
    public enum DosingDecisionDataQueryResult {
        case success(QueryAnchor, [StoredDosingDecisionData])
        case failure(Error)
    }
    
    public func executeDosingDecisionDataQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (DosingDecisionDataQueryResult) -> Void) {
        dataAccessQueue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryResult = [StoredDosingDecisionData]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, queryResult))
                return
            }

            self.store.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<DosingDecisionObject> = DosingDecisionObject.fetchRequest()

                storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                storedRequest.fetchLimit = limit

                do {
                    let stored = try self.store.managedObjectContext.fetch(storedRequest)
                    if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.modificationCounter = modificationCounter
                    }
                    queryResult.append(contentsOf: stored.compactMap { StoredDosingDecisionData(date: $0.date, data: $0.data) })
                } catch let error {
                    queryError = error
                    return
                }
            }

            if let queryError = queryError {
                completion(.failure(queryError))
                return
            }

            completion(.success(queryAnchor, queryResult))
        }
    }
}

public struct StoredDosingDecisionData {
    public let date: Date
    public let data: Data

    public init(date: Date, data: Data) {
        self.date = date
        self.data = data
    }
}

public struct StoredDosingDecision {
    public let date: Date
    public let insulinOnBoard: InsulinValue?
    public let carbsOnBoard: CarbValue?
    public let scheduleOverride: TemporaryScheduleOverride?
    public let glucoseTargetRangeSchedule: GlucoseRangeSchedule?
    public let effectiveGlucoseTargetRangeSchedule: GlucoseRangeSchedule?
    public let predictedGlucose: [PredictedGlucoseValue]?
    public let predictedGlucoseIncludingPendingInsulin: [PredictedGlucoseValue]?
    public let lastReservoirValue: LastReservoirValue?
    public let manualGlucose: SimpleGlucoseValue?
    public let originalCarbEntry: StoredCarbEntry?
    public let carbEntry: StoredCarbEntry?
    public let recommendedTempBasal: TempBasalRecommendationWithDate?
    public let recommendedBolus: BolusRecommendationWithDate?
    public let requestedBolus: Double?
    public let pumpManagerStatus: PumpManagerStatus?
    public let notificationSettings: NotificationSettings?
    public let deviceSettings: DeviceSettings?
    public let errors: [Error]?
    public let syncIdentifier: String

    public init(date: Date = Date(),
                insulinOnBoard: InsulinValue? = nil,
                carbsOnBoard: CarbValue? = nil,
                scheduleOverride: TemporaryScheduleOverride? = nil,
                glucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
                effectiveGlucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
                predictedGlucose: [PredictedGlucoseValue]? = nil,
                predictedGlucoseIncludingPendingInsulin: [PredictedGlucoseValue]? = nil,
                lastReservoirValue: LastReservoirValue? = nil,
                manualGlucose: SimpleGlucoseValue? = nil,
                originalCarbEntry: StoredCarbEntry? = nil,
                carbEntry: StoredCarbEntry? = nil,
                recommendedTempBasal: TempBasalRecommendationWithDate? = nil,
                recommendedBolus: BolusRecommendationWithDate? = nil,
                requestedBolus: Double? = nil,
                pumpManagerStatus: PumpManagerStatus? = nil,
                notificationSettings: NotificationSettings? = nil,
                deviceSettings: DeviceSettings? = nil,
                errors: [Error]? = nil,
                syncIdentifier: String = UUID().uuidString) {
        self.date = date
        self.insulinOnBoard = insulinOnBoard
        self.carbsOnBoard = carbsOnBoard
        self.scheduleOverride = scheduleOverride
        self.glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        self.effectiveGlucoseTargetRangeSchedule = effectiveGlucoseTargetRangeSchedule
        self.predictedGlucose = predictedGlucose
        self.predictedGlucoseIncludingPendingInsulin = predictedGlucoseIncludingPendingInsulin
        self.lastReservoirValue = lastReservoirValue
        self.manualGlucose = manualGlucose
        self.originalCarbEntry = originalCarbEntry
        self.carbEntry = carbEntry
        self.recommendedTempBasal = recommendedTempBasal
        self.recommendedBolus = recommendedBolus
        self.requestedBolus = requestedBolus
        self.pumpManagerStatus = pumpManagerStatus
        self.notificationSettings = notificationSettings
        self.deviceSettings = deviceSettings
        self.errors = errors
        self.syncIdentifier = syncIdentifier
    }

    public struct LastReservoirValue: Codable {
        public let startDate: Date
        public let unitVolume: Double

        public init(startDate: Date, unitVolume: Double) {
            self.startDate = startDate
            self.unitVolume = unitVolume
        }
    }

    public struct TempBasalRecommendationWithDate: Codable {
        public let recommendation: TempBasalRecommendation
        public let date: Date

        public init(recommendation: TempBasalRecommendation, date: Date) {
            self.recommendation = recommendation
            self.date = date
        }
    }

    public struct BolusRecommendationWithDate: Codable {
        public let recommendation: BolusRecommendation
        public let date: Date

        public init(recommendation: BolusRecommendation, date: Date) {
            self.recommendation = recommendation
            self.date = date
        }
    }

    public struct DeviceSettings: Codable, Equatable {
        let name: String
        let systemName: String
        let systemVersion: String
        let model: String
        let modelIdentifier: String
        let batteryLevel: Float?
        let batteryState: BatteryState?

        public init(name: String, systemName: String, systemVersion: String, model: String, modelIdentifier: String, batteryLevel: Float? = nil, batteryState: BatteryState? = nil) {
            self.name = name
            self.systemName = systemName
            self.systemVersion = systemVersion
            self.model = model
            self.modelIdentifier = modelIdentifier
            self.batteryLevel = batteryLevel
            self.batteryState = batteryState
        }

        public enum BatteryState: String, Codable {
            case unknown
            case unplugged
            case charging
            case full
        }
    }
}

// MARK: - Critical Event Log Export

extension DosingDecisionStore {
    private var exportProgressUnitCountPerObject: Int64 { 33 }
    private var exportFetchLimit: Int { Int(criticalEventLogExportProgressUnitCountPerFetch / exportProgressUnitCountPerObject) }

    public func exportProgressTotalUnitCount(startDate: Date, endDate: Date? = nil) -> Result<Int64, Error> {
        var result: Result<Int64, Error>?

        self.store.managedObjectContext.performAndWait {
            do {
                let request: NSFetchRequest<DosingDecisionObject> = DosingDecisionObject.fetchRequest()
                request.predicate = self.exportDatePredicate(startDate: startDate, endDate: endDate)

                let objectCount = try self.store.managedObjectContext.count(for: request)
                result = .success(Int64(objectCount) * exportProgressUnitCountPerObject)
            } catch let error {
                result = .failure(error)
            }
        }

        return result!
    }

    public func export(startDate: Date, endDate: Date, using encoder: @escaping ([DosingDecisionObject]) throws -> Void, progress: Progress) -> Error? {
        var modificationCounter: Int64 = 0
        var fetching = true
        var error: Error?

        while fetching && error == nil {
            self.store.managedObjectContext.performAndWait {
                do {
                    guard !progress.isCancelled else {
                        throw CriticalEventLogError.cancelled
                    }

                    let request: NSFetchRequest<DosingDecisionObject> = DosingDecisionObject.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "modificationCounter > %d", modificationCounter),
                                                                                            self.exportDatePredicate(startDate: startDate, endDate: endDate)])
                    request.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                    request.fetchLimit = self.exportFetchLimit

                    let objects = try self.store.managedObjectContext.fetch(request)
                    if objects.isEmpty {
                        fetching = false
                        return
                    }

                    try encoder(objects)

                    modificationCounter = objects.last!.modificationCounter

                    progress.completedUnitCount += Int64(objects.count) * exportProgressUnitCountPerObject
                } catch let fetchError {
                    error = fetchError
                }
            }
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

extension DosingDecisionStore {
    public func addStoredDosingDecisionDatas(dosingDecisionDatas: [StoredDosingDecisionData], completion: @escaping (Error?) -> Void) {
        guard !dosingDecisionDatas.isEmpty else {
            completion(nil)
            return
        }

        dataAccessQueue.async {
            var error: Error?

            self.store.managedObjectContext.performAndWait {
                for dosingDecisionData in dosingDecisionDatas {
                    let object = DosingDecisionObject(context: self.store.managedObjectContext)
                    object.date = dosingDecisionData.date
                    object.data = dosingDecisionData.data
                }
                error = self.store.save()
            }

            guard error == nil else {
                completion(error)
                return
            }

            self.log.info("Added %d DosingDecisionObjects", dosingDecisionDatas.count)
            self.delegate?.dosingDecisionStoreHasUpdatedDosingDecisionData(self)
            completion(nil)
        }
    }
}
