//
//  DosingDecisionStore.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public protocol DosingDecisionStoreDelegate: AnyObject {
    
    /**
     Informs the delegate that the dosing decision store has updated dosing decision data.
     
     - Parameter dosingDecisionStore: The dosing decision store that has updated dosing decision data.
     */
    func dosingDecisionStoreHasUpdatedDosingDecisionData(_ dosingDecisionStore: DosingDecisionStore)
    
}

public protocol DosingDecisionStoreCacheStore: AnyObject {

    /// The dosing decision store modification counter
    var dosingDecisionStoreModificationCounter: Int64? { get set }

}

public class DosingDecisionStore {
    
    public weak var delegate: DosingDecisionStoreDelegate?
    
    private let lock = UnfairLock()

    private let storeCache: DosingDecisionStoreCacheStore

    private var dosingDecision: [Int64: StoredDosingDecision]
    
    private var modificationCounter: Int64 {
        didSet {
            storeCache.dosingDecisionStoreModificationCounter = modificationCounter
        }
    }
    
    public init(storeCache: DosingDecisionStoreCacheStore) {
        self.storeCache = storeCache
        self.dosingDecision = [:]
        self.modificationCounter = storeCache.dosingDecisionStoreModificationCounter ?? 0
    }
    
    public func storeDosingDecision(_ dosingDecision: StoredDosingDecision, completion: @escaping () -> Void) {
        lock.withLock {
            self.modificationCounter += 1
            self.dosingDecision[self.modificationCounter] = dosingDecision
        }
        self.delegate?.dosingDecisionStoreHasUpdatedDosingDecisionData(self)
        completion()
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
        var queryAnchor = queryAnchor ?? QueryAnchor()
        var queryResult = [StoredDosingDecision]()

        guard limit > 0 else {
            completion(.success(queryAnchor, queryResult))
            return
        }

        lock.withLock {
            if queryAnchor.modificationCounter < self.modificationCounter {
                var modificationCounter = queryAnchor.modificationCounter
                while modificationCounter < self.modificationCounter && queryResult.count < limit {
                    modificationCounter += 1
                    if let dosingDecision = self.dosingDecision[modificationCounter] {
                        queryResult.append(dosingDecision)
                    }
                }
                queryAnchor.modificationCounter = modificationCounter
            }
        }
        
        completion(.success(queryAnchor, queryResult))
    }
    
}

public struct StoredDosingDecision {
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
    public var errors: [Error]?
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

    public struct LastReservoirValue {
        public let startDate: Date
        public let unitVolume: Double

        public init(startDate: Date, unitVolume: Double) {
            self.startDate = startDate
            self.unitVolume = unitVolume
        }
    }

    public struct TempBasalRecommendationWithDate {
        public let recommendation: TempBasalRecommendation
        public let date: Date

        public init(recommendation: TempBasalRecommendation, date: Date) {
            self.recommendation = recommendation
            self.date = date
        }
    }

    public struct BolusRecommendationWithDate {
        public let recommendation: BolusRecommendation
        public let date: Date

        public init(recommendation: BolusRecommendation, date: Date) {
            self.recommendation = recommendation
            self.date = date
        }
    }
}

extension UserDefaults: DosingDecisionStoreCacheStore {
    
    private enum Key: String {
        case dosingDecisionStoreModificationCounter = "com.loopkit.DosingDecisionStore.ModificationCounter"
    }
    
    public var dosingDecisionStoreModificationCounter: Int64? {
        get {
            guard let value = object(forKey: Key.dosingDecisionStoreModificationCounter.rawValue) as? NSNumber else {
                return nil
            }
            return value.int64Value
        }
        set {
            if let newValue = newValue {
                set(NSNumber(value: newValue), forKey: Key.dosingDecisionStoreModificationCounter.rawValue)
            } else {
                removeObject(forKey: Key.dosingDecisionStoreModificationCounter.rawValue)
            }
        }
    }
    
}
