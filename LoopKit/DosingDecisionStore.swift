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
import HealthKit

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

            self.purgeExpiredDosingDecisionObjects()

            self.delegate?.dosingDecisionStoreHasUpdatedDosingDecisionData(self)
            completion()
        }
    }

    private var expireDate: Date {
        return Date(timeIntervalSinceNow: -expireAfter)
    }

    private func purgeExpiredDosingDecisionObjects() {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        store.managedObjectContext.performAndWait {
            do {
                let fetchRequest: NSFetchRequest<DosingDecisionObject> = DosingDecisionObject.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "date < %@", expireDate as NSDate)
                let count = try self.store.managedObjectContext.deleteObjects(matching: fetchRequest)
                self.log.info("Deleted %d DosingDecisionObjects", count)
            } catch let error {
                self.log.error("Unable to purge DosingDecisionObjects: %@", String(describing: error))
            }
        }
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
    public let glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule?
    public let predictedGlucose: [PredictedGlucoseValue]?
    public let predictedGlucoseIncludingPendingInsulin: [PredictedGlucoseValue]?
    public let lastReservoirValue: LastReservoirValue?
    public let recommendedTempBasal: TempBasalRecommendationWithDate?
    public let recommendedBolus: BolusRecommendationWithDate?
    public let pumpManagerStatus: PumpManagerStatus?
    public let errors: [Error]?
    public let syncIdentifier: String

    public init(date: Date = Date(),
                insulinOnBoard: InsulinValue? = nil,
                carbsOnBoard: CarbValue? = nil,
                scheduleOverride: TemporaryScheduleOverride? = nil,
                glucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
                glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule? = nil,
                predictedGlucose: [PredictedGlucoseValue]? = nil,
                predictedGlucoseIncludingPendingInsulin: [PredictedGlucoseValue]? = nil,
                lastReservoirValue: LastReservoirValue? = nil,
                recommendedTempBasal: TempBasalRecommendationWithDate? = nil,
                recommendedBolus: BolusRecommendationWithDate? = nil,
                pumpManagerStatus: PumpManagerStatus? = nil,
                errors: [Error]? = nil,
                syncIdentifier: String = UUID().uuidString) {
        self.date = date
        self.insulinOnBoard = insulinOnBoard
        self.carbsOnBoard = carbsOnBoard
        self.scheduleOverride = scheduleOverride
        self.glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        self.glucoseTargetRangeScheduleApplyingOverrideIfActive = glucoseTargetRangeScheduleApplyingOverrideIfActive
        self.predictedGlucose = predictedGlucose
        self.predictedGlucoseIncludingPendingInsulin = predictedGlucoseIncludingPendingInsulin
        self.lastReservoirValue = lastReservoirValue
        self.recommendedTempBasal = recommendedTempBasal
        self.recommendedBolus = recommendedBolus
        self.pumpManagerStatus = pumpManagerStatus
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
}

extension NSManagedObjectContext {
    fileprivate func deleteObjects<T>(matching fetchRequest: NSFetchRequest<T>) throws -> Int where T: NSManagedObject {
        let objects = try fetch(fetchRequest)
        objects.forEach { delete($0) }
        if hasChanges {
            try save()
        }
        return objects.count
    }
}
