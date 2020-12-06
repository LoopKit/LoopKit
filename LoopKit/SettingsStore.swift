//
//  SettingsStore.swift
//  LoopKit
//
//  Created by Darin Krauss on 10/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import os.log
import Foundation
import CoreData
import HealthKit

public protocol SettingsStoreDelegate: AnyObject {
    /**
     Informs the delegate that the settings store has updated settings data.
     
     - Parameter settingsStore: The settings store that has updated settings data.
     */
    func settingsStoreHasUpdatedSettingsData(_ settingsStore: SettingsStore)

}

public class SettingsStore {
    public weak var delegate: SettingsStoreDelegate?
    
    private let store: PersistenceController
    private let expireAfter: TimeInterval
    private let dataAccessQueue = DispatchQueue(label: "com.loopkit.SettingsStore.dataAccessQueue", qos: .utility)
    private let log = OSLog(category: "SettingsStore")

    public init(store: PersistenceController, expireAfter: TimeInterval) {
        self.store = store
        self.expireAfter = expireAfter
    }
    
    public func storeSettings(_ settings: StoredSettings, completion: @escaping () -> Void) {
        dataAccessQueue.async {
            if let data = self.encodeSettings(settings) {
                self.store.managedObjectContext.performAndWait {
                    let object = SettingsObject(context: self.store.managedObjectContext)
                    object.data = data
                    object.date = settings.date
                    self.store.save()
                }
            }

            self.purgeExpiredSettings()
            completion()
        }
    }

    public var expireDate: Date {
        return Date(timeIntervalSinceNow: -expireAfter)
    }

    private func purgeExpiredSettings() {
        purgeSettingsObjects(before: expireDate)
    }

    public func purgeSettings(before date: Date, completion: @escaping (Error?) -> Void) {
        dataAccessQueue.async {
            self.purgeSettingsObjects(before: date, completion: completion)
        }
    }

    private func purgeSettingsObjects(before date: Date, completion: ((Error?) -> Void)? = nil) {
        dispatchPrecondition(condition: .onQueue(dataAccessQueue))

        var purgeError: Error?

        store.managedObjectContext.performAndWait {
            do {
                let count = try self.store.managedObjectContext.purgeObjects(of: SettingsObject.self, matching: NSPredicate(format: "date < %@", date as NSDate))
                self.log.info("Purged %d SettingsObjects", count)
            } catch let error {
                self.log.error("Unable to purge SettingsObjects: %{public}@", String(describing: error))
                purgeError = error
            }
        }

        if let purgeError = purgeError {
            completion?(purgeError)
            return
        }

        delegate?.settingsStoreHasUpdatedSettingsData(self)
        completion?(nil)
    }

    private static var encoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }()

    private func encodeSettings(_ settings: StoredSettings) -> Data? {
        do {
            return try SettingsStore.encoder.encode(settings)
        } catch let error {
            self.log.error("Error encoding StoredSettings: %@", String(describing: error))
            return nil
        }
    }

    private static var decoder = PropertyListDecoder()

    private func decodeSettings(fromData data: Data) -> StoredSettings? {
        do {
            return try SettingsStore.decoder.decode(StoredSettings.self, from: data)
        } catch let error {
            self.log.error("Error decoding StoredSettings: %@", String(describing: error))
            return nil
        }
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
        dataAccessQueue.async {
            var queryAnchor = queryAnchor ?? QueryAnchor()
            var queryResult = [StoredSettings]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, queryResult))
                return
            }

            self.store.managedObjectContext.performAndWait {
                let storedRequest: NSFetchRequest<SettingsObject> = SettingsObject.fetchRequest()

                storedRequest.predicate = NSPredicate(format: "modificationCounter > %d", queryAnchor.modificationCounter)
                storedRequest.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                storedRequest.fetchLimit = limit

                do {
                    let stored = try self.store.managedObjectContext.fetch(storedRequest)
                    if let modificationCounter = stored.max(by: { $0.modificationCounter < $1.modificationCounter })?.modificationCounter {
                        queryAnchor.modificationCounter = modificationCounter
                    }
                    queryResult.append(contentsOf: stored.compactMap { self.decodeSettings(fromData: $0.data) })
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
    public let insulinModel: StoredInsulinModel?
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
                insulinModel: StoredInsulinModel? = nil,
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
}

extension StoredSettings: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var bloodGlucoseUnit: HKUnit?
        if let bloodGlucoseUnitString = try container.decodeIfPresent(String.self, forKey: .bloodGlucoseUnit) {
            bloodGlucoseUnit = HKUnit(from: bloodGlucoseUnitString)
        }
        self.init(date: try container.decode(Date.self, forKey: .date),
                  dosingEnabled: try container.decode(Bool.self, forKey: .dosingEnabled),
                  glucoseTargetRangeSchedule: try container.decodeIfPresent(GlucoseRangeSchedule.self, forKey: .glucoseTargetRangeSchedule),
                  preMealTargetRange: try container.decodeIfPresent(DoubleRange.self, forKey: .preMealTargetRange),
                  workoutTargetRange: try container.decodeIfPresent(DoubleRange.self, forKey: .workoutTargetRange),
                  overridePresets: try container.decodeIfPresent([TemporaryScheduleOverridePreset].self, forKey: .overridePresets),
                  scheduleOverride: try container.decodeIfPresent(TemporaryScheduleOverride.self, forKey: .scheduleOverride),
                  preMealOverride: try container.decodeIfPresent(TemporaryScheduleOverride.self, forKey: .preMealOverride),
                  maximumBasalRatePerHour: try container.decodeIfPresent(Double.self, forKey: .maximumBasalRatePerHour),
                  maximumBolus: try container.decodeIfPresent(Double.self, forKey: .maximumBolus),
                  suspendThreshold: try container.decodeIfPresent(GlucoseThreshold.self, forKey: .suspendThreshold),
                  deviceToken: try container.decodeIfPresent(String.self, forKey: .deviceToken),
                  insulinModel: try container.decodeIfPresent(StoredInsulinModel.self, forKey: .insulinModel),
                  basalRateSchedule: try container.decodeIfPresent(BasalRateSchedule.self, forKey: .basalRateSchedule),
                  insulinSensitivitySchedule: try container.decodeIfPresent(InsulinSensitivitySchedule.self, forKey: .insulinSensitivitySchedule),
                  carbRatioSchedule: try container.decodeIfPresent(CarbRatioSchedule.self, forKey: .carbRatioSchedule),
                  bloodGlucoseUnit: bloodGlucoseUnit,
                  syncIdentifier: try container.decode(String.self, forKey: .syncIdentifier))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(dosingEnabled, forKey: .dosingEnabled)
        try container.encodeIfPresent(glucoseTargetRangeSchedule, forKey: .glucoseTargetRangeSchedule)
        try container.encodeIfPresent(preMealTargetRange, forKey: .preMealTargetRange)
        try container.encodeIfPresent(workoutTargetRange, forKey: .workoutTargetRange)
        try container.encodeIfPresent(overridePresets, forKey: .overridePresets)
        try container.encodeIfPresent(scheduleOverride, forKey: .scheduleOverride)
        try container.encodeIfPresent(preMealOverride, forKey: .preMealOverride)
        try container.encodeIfPresent(maximumBasalRatePerHour, forKey: .maximumBasalRatePerHour)
        try container.encodeIfPresent(maximumBolus, forKey: .maximumBolus)
        try container.encodeIfPresent(suspendThreshold, forKey: .suspendThreshold)
        try container.encodeIfPresent(deviceToken, forKey: .deviceToken)
        try container.encodeIfPresent(insulinModel, forKey: .insulinModel)
        try container.encodeIfPresent(basalRateSchedule, forKey: .basalRateSchedule)
        try container.encodeIfPresent(insulinSensitivitySchedule, forKey: .insulinSensitivitySchedule)
        try container.encodeIfPresent(carbRatioSchedule, forKey: .carbRatioSchedule)
        try container.encodeIfPresent(bloodGlucoseUnit?.unitString, forKey: .bloodGlucoseUnit)
        try container.encode(syncIdentifier, forKey: .syncIdentifier)
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case dosingEnabled
        case glucoseTargetRangeSchedule
        case preMealTargetRange
        case workoutTargetRange
        case overridePresets
        case scheduleOverride
        case preMealOverride
        case maximumBasalRatePerHour
        case maximumBolus
        case suspendThreshold
        case deviceToken
        case insulinModel
        case basalRateSchedule
        case insulinSensitivitySchedule
        case carbRatioSchedule
        case bloodGlucoseUnit
        case syncIdentifier
    }
}

// MARK: - Critical Event Log Export

extension SettingsStore: CriticalEventLog {
    private var exportProgressUnitCountPerObject: Int64 { 11 }
    private var exportFetchLimit: Int { Int(criticalEventLogExportProgressUnitCountPerFetch / exportProgressUnitCountPerObject) }

    public var exportName: String { "Settings.json" }

    public func exportProgressTotalUnitCount(startDate: Date, endDate: Date? = nil) -> Result<Int64, Error> {
        var result: Result<Int64, Error>?

        self.store.managedObjectContext.performAndWait {
            do {
                let request: NSFetchRequest<SettingsObject> = SettingsObject.fetchRequest()
                request.predicate = self.exportDatePredicate(startDate: startDate, endDate: endDate)

                let objectCount = try self.store.managedObjectContext.count(for: request)
                result = .success(Int64(objectCount) * exportProgressUnitCountPerObject)
            } catch let error {
                result = .failure(error)
            }
        }

        return result!
    }

    public func export(startDate: Date, endDate: Date, to stream: OutputStream, progress: Progress) -> Error? {
        let encoder = JSONStreamEncoder(stream: stream)
        var modificationCounter: Int64 = 0
        var fetching = true
        var error: Error?

        while fetching && error == nil {
            self.store.managedObjectContext.performAndWait {
                do {
                    guard !progress.isCancelled else {
                        throw CriticalEventLogError.cancelled
                    }

                    let request: NSFetchRequest<SettingsObject> = SettingsObject.fetchRequest()
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "modificationCounter > %d", modificationCounter),
                                                                                            self.exportDatePredicate(startDate: startDate, endDate: endDate)])
                    request.sortDescriptors = [NSSortDescriptor(key: "modificationCounter", ascending: true)]
                    request.fetchLimit = self.exportFetchLimit

                    let objects = try self.store.managedObjectContext.fetch(request)
                    if objects.isEmpty {
                        fetching = false
                        return
                    }

                    try encoder.encode(objects)

                    modificationCounter = objects.last!.modificationCounter

                    progress.completedUnitCount += Int64(objects.count) * exportProgressUnitCountPerObject
                } catch let fetchError {
                    error = fetchError
                }
            }
        }

        if let closeError = encoder.close(), error == nil {
            error = closeError
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

extension SettingsStore {
    public func addStoredSettings(settings: [StoredSettings], completion: @escaping (Error?) -> Void) {
        guard !settings.isEmpty else {
            completion(nil)
            return
        }

        dataAccessQueue.async {
            var error: Error?

            self.store.managedObjectContext.performAndWait {
                for setting in settings {
                    guard let data = self.encodeSettings(setting) else {
                        continue
                    }
                    let object = SettingsObject(context: self.store.managedObjectContext)
                    object.data = data
                    object.date = setting.date
                }
                error = self.store.save()
            }

            guard error == nil else {
                completion(error)
                return
            }

            self.log.info("Added %d SettingsObjects", settings.count)
            self.delegate?.settingsStoreHasUpdatedSettingsData(self)
            completion(nil)
        }
    }
}
