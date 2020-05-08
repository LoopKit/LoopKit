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
    private let log = OSLog(category: "DosingDecisionStore")

    public init(store: PersistenceController, expireAfter: TimeInterval) {
        self.store = store
        self.expireAfter = expireAfter
    }

    public func storeDosingDecision(_ dosingDecision: StoredDosingDecision, completion: @escaping () -> Void) {
        dataAccessQueue.async {
            if let data = self.encodeDosingDecision(dosingDecision) {
                self.store.managedObjectContext.performAndWait {
                    let object = DosingDecisionObject(context: self.store.managedObjectContext)
                    object.data = data
                    object.date = dosingDecision.date
                    self.store.save()
                }
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

    private func encodeDosingDecision(_ dosingDecision: StoredDosingDecision) -> Data? {
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            return try encoder.encode(dosingDecision)
        } catch let error {
            self.log.error("Error encoding StoredDosingDecision: %@", String(describing: error))
            return nil
        }
    }

    private func decodeDosingDecision(fromData data: Data) -> StoredDosingDecision? {
        do {
            let decoder = PropertyListDecoder()
            return try decoder.decode(StoredDosingDecision.self, from: data)
        } catch let error {
            self.log.error("Error decoding StoredDosingDecision: %@", String(describing: error))
            return nil
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
    
    public enum DosingDecisionQueryResult {
        case success(QueryAnchor, [StoredDosingDecision])
        case failure(Error)
    }
    
    public func executeDosingDecisionQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (DosingDecisionQueryResult) -> Void) {
        dataAccessQueue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryResult = [StoredDosingDecision]()
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
                    queryResult.append(contentsOf: stored.compactMap { self.decodeDosingDecision(fromData: $0.data) })
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

public struct StoredDosingDecision: Codable {
    public let date: Date
    public var insulinOnBoard: InsulinValue?
    public var carbsOnBoard: CarbValue?
    public var scheduleOverride: TemporaryScheduleOverride?
    public var glucoseTargetRangeSchedule: GlucoseRangeSchedule?
    public var glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule?
    public var predictedGlucose: [PredictedGlucoseValue]?
    public var predictedGlucoseIncludingPendingInsulin: [PredictedGlucoseValue]?
    public var lastReservoirValue: LastReservoirValue?
    public var recommendedTempBasal: TempBasalRecommendationWithDate?
    public var recommendedBolus: BolusRecommendationWithDate?
    public var pumpManagerStatus: PumpManagerStatus?
    public var errors: [CodableError]?
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
        self.errors = errors?.map { CodableError($0) }
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

    // TODO: Temporary placeholder for error serialization. Will be fixed with https://tidepool.atlassian.net/browse/LOOP-1144
    public struct CodableError: Error, CustomStringConvertible, Codable {
        private let errorString: String

        init(_ error: Error) {
            self.errorString = String(describing: error)
        }

        public var description: String { return errorString }
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
