//
//  SettingsStore.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public protocol SettingsStoreDelegate: AnyObject {
    
    /**
     Informs the delegate that the settings store has updated settings data.
     
     - Parameter settingsStore: The settings store that has updated settings data.
     */
    func settingsStoreHasUpdatedSettingsData(_ settingsStore: SettingsStore)
    
}

public protocol SettingsStoreCacheStore: AnyObject {

    /// The settings store modification counter
    var settingsStoreModificationCounter: Int64? { get set }
    
}

public class SettingsStore {
    
    public weak var delegate: SettingsStoreDelegate?
    
    private let lock = UnfairLock()
    
    private let storeCache: SettingsStoreCacheStore
    
    private var settings: [Int64: StoredSettings]
    
    private var modificationCounter: Int64 {
        didSet {
            storeCache.settingsStoreModificationCounter = modificationCounter
        }
    }
    
    public init(storeCache: SettingsStoreCacheStore) {
        self.storeCache = storeCache
        self.settings = [:]
        self.modificationCounter = storeCache.settingsStoreModificationCounter ?? 0
    }
    
    public func storeSettings(_ settings: StoredSettings, completion: @escaping () -> Void) {
        lock.withLock {
            self.modificationCounter += 1
            self.settings[self.modificationCounter] = settings
        }
        self.delegate?.settingsStoreHasUpdatedSettingsData(self)
        completion()
    }
    
}

extension SettingsStore {
    
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
    
    public enum SettingsQueryResult {
        case success(QueryAnchor, [StoredSettings])
        case failure(Error)
    }
    
    public func executeSettingsQuery(fromQueryAnchor queryAnchor: QueryAnchor?, limit: Int, completion: @escaping (SettingsQueryResult) -> Void) {
        var queryAnchor = queryAnchor ?? QueryAnchor()
        var queryResult = [StoredSettings]()

        guard limit > 0 else {
            completion(.success(queryAnchor, queryResult))
            return
        }

        lock.withLock {
            if queryAnchor.modificationCounter < self.modificationCounter {
                var modificationCounter = queryAnchor.modificationCounter
                while modificationCounter < self.modificationCounter && queryResult.count < limit {
                    modificationCounter += 1
                    if let settings = self.settings[modificationCounter] {
                        queryResult.append(settings)
                    }
                }
                queryAnchor.modificationCounter = modificationCounter
            }
        }

        completion(.success(queryAnchor, queryResult))
    }
    
}

public struct StoredSettings {
    public let date: Date
    public let dosingEnabled: Bool
    public let glucoseTargetRangeSchedule: GlucoseRangeSchedule?
    public let preMealTargetRange: DoubleRange?
    public let workoutTargetRange: DoubleRange?
    public let overridePresets: [TemporaryScheduleOverridePreset]?
    public let scheduleOverride: TemporaryScheduleOverride?
    public let preMealOverride: TemporaryScheduleOverride?
    public let maximumBasalRatePerHour: Double?
    public let maximumBolus: Double?
    public let suspendThreshold: GlucoseThreshold?
    public let deviceToken: String?
    public let insulinModel: InsulinModel?
    public let basalRateSchedule: BasalRateSchedule?
    public let insulinSensitivitySchedule: InsulinSensitivitySchedule?
    public let carbRatioSchedule: CarbRatioSchedule?
    public let bloodGlucoseUnit: HKUnit?
    public let syncIdentifier: String

    public init(date: Date = Date(),
                dosingEnabled: Bool = false,
                glucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
                preMealTargetRange: DoubleRange? = nil,
                workoutTargetRange: DoubleRange? = nil,
                overridePresets: [TemporaryScheduleOverridePreset]? = nil,
                scheduleOverride: TemporaryScheduleOverride? = nil,
                preMealOverride: TemporaryScheduleOverride? = nil,
                maximumBasalRatePerHour: Double? = nil,
                maximumBolus: Double? = nil,
                suspendThreshold: GlucoseThreshold? = nil,
                deviceToken: String? = nil,
                insulinModel: InsulinModel? = nil,
                basalRateSchedule: BasalRateSchedule? = nil,
                insulinSensitivitySchedule: InsulinSensitivitySchedule? = nil,
                carbRatioSchedule: CarbRatioSchedule? = nil,
                bloodGlucoseUnit: HKUnit? = nil,
                syncIdentifier: String = UUID().uuidString) {
        self.date = date
        self.dosingEnabled = dosingEnabled
        self.glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        self.preMealTargetRange = preMealTargetRange
        self.workoutTargetRange = workoutTargetRange
        self.overridePresets = overridePresets
        self.scheduleOverride = scheduleOverride
        self.preMealOverride = preMealOverride
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.maximumBolus = maximumBolus
        self.suspendThreshold = suspendThreshold
        self.deviceToken = deviceToken
        self.insulinModel = insulinModel
        self.basalRateSchedule = basalRateSchedule
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
        self.carbRatioSchedule = carbRatioSchedule
        self.bloodGlucoseUnit = bloodGlucoseUnit
        self.syncIdentifier = syncIdentifier
    }

    public struct InsulinModel {
        public enum ModelType: String {
            case fiasp
            case rapidAdult
            case rapidChild
            case walsh
        }
        
        public let modelType: ModelType
        public let actionDuration: TimeInterval
        public let peakActivity: TimeInterval?

        public init(modelType: ModelType, actionDuration: TimeInterval, peakActivity: TimeInterval? = nil) {
            self.modelType = modelType
            self.actionDuration = actionDuration
            self.peakActivity = peakActivity
        }
    }
}

extension UserDefaults: SettingsStoreCacheStore {
    
    private enum Key: String {
        case settingsStoreModificationCounter = "com.loopkit.SettingsStore.ModificationCounter"
    }
    
    public var settingsStoreModificationCounter: Int64? {
        get {
            guard let value = object(forKey: Key.settingsStoreModificationCounter.rawValue) as? NSNumber else {
                return nil
            }
            return value.int64Value
        }
        set {
            if let newValue = newValue {
                set(NSNumber(value: newValue), forKey: Key.settingsStoreModificationCounter.rawValue)
            } else {
                removeObject(forKey: Key.settingsStoreModificationCounter.rawValue)
            }
        }
    }
    
}
