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
                let startModificationCounter = queryAnchor.modificationCounter + 1
                var endModificationCounter = self.modificationCounter
                if limit <= endModificationCounter - startModificationCounter {
                    endModificationCounter = queryAnchor.modificationCounter + Int64(limit)
                }
                for modificationCounter in (startModificationCounter...endModificationCounter) {
                    if let dosingDecision = self.dosingDecision[modificationCounter] {
                        queryResult.append(dosingDecision)
                    }
                }
                
                queryAnchor.modificationCounter = endModificationCounter
            }
        }
        
        completion(.success(queryAnchor, queryResult))
    }
    
}

public struct StoredDosingDecision {
    
    public let date: Date = Date()
    
    public var insulinOnBoard: InsulinValue?
    
    public var carbsOnBoard: CarbValue?
    
    public var predictedGlucose: [PredictedGlucoseValue]?
    
    public var tempBasalRecommendationDate: TempBasalRecommendationDate?
    
    public var recommendedBolus: Double?
    
    public var lastReservoirValue: LastReservoirValue?
    
    public var pumpManagerStatus: PumpManagerStatus?
    
    public var glucoseTargetRangeSchedule: GlucoseRangeSchedule?
    
    public var scheduleOverride: TemporaryScheduleOverride?
    
    public var glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule?
    
    public var error: Error?

    public var syncIdentifier: String

    public var syncVersion: Int

    public init() {
        self.syncIdentifier = UUID().uuidString
        self.syncVersion = 1
    }
    
}

public struct TempBasalRecommendationDate {
    
    public let recommendation: TempBasalRecommendation
    
    public let date: Date
    
    public init(recommendation: TempBasalRecommendation, date: Date) {
        self.recommendation = recommendation
        self.date = date
    }
    
}

public struct LastReservoirValue {
    
    public let startDate: Date
    
    public let unitVolume: Double
    
    public init(startDate: Date, unitVolume: Double) {
        self.startDate = startDate
        self.unitVolume = unitVolume
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
