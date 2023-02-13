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
    
    private static var encoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }()

    private func encodeDosingDecision(_ dosingDecision: StoredDosingDecision) -> Data? {
        do {
            return try Self.encoder.encode(dosingDecision)
        } catch let error {
            self.log.error("Error encoding StoredDosingDecision: %@", String(describing: error))
            return nil
        }
    }

    private static var decoder = PropertyListDecoder()

    private func decodeDosingDecision(fromData data: Data) -> StoredDosingDecision? {
        do {
            return try Self.decoder.decode(StoredDosingDecision.self, from: data)
        } catch let error {
            self.log.error("Error decoding StoredDosingDecision: %@", String(describing: error))
            return nil
        }
    }
}

extension DosingDecisionStore {
    public struct QueryAnchor: Equatable, RawRepresentable {
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
            var queryResult = [StoredDosingDecisionData]()
            var queryError: Error?

            guard limit > 0 else {
                completion(.success(queryAnchor, []))
                return
            }

            let enqueueTime = DispatchTime.now()

            self.store.managedObjectContext.performAndWait {
                let startTime = DispatchTime.now()

                defer {
                    let endTime = DispatchTime.now()
                    let queueWait = Double(startTime.uptimeNanoseconds - enqueueTime.uptimeNanoseconds) / 1_000_000_000
                    let fetchWait = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
                    self.log.debug("executeDosingDecisionQuery (anchor = %{public}@: queueWait(%.03f), fetch(%.03f)", String(describing: queryAnchor), queueWait, fetchWait)
                }

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

            // Decoding a large number of dosing decision can be very CPU intensive and may take considerable wall clock time.
            // Do not block DosingDecisionStore dataAccessQueue. Perform work and callback in global utility queue.
            DispatchQueue.global(qos: .utility).async {
                completion(.success(queryAnchor, queryResult.compactMap { self.decodeDosingDecision(fromData: $0.data) }))
            }
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

public typealias HistoricalGlucoseValue = PredictedGlucoseValue

public struct StoredDosingDecision {
    public var date: Date
    public var controllerTimeZone: TimeZone
    public var reason: String
    public var settings: Settings?
    public var scheduleOverride: TemporaryScheduleOverride?
    public var controllerStatus: ControllerStatus?
    public var pumpManagerStatus: PumpManagerStatus?
    public var pumpStatusHighlight: StoredDeviceHighlight?
    public var cgmManagerStatus: CGMManagerStatus?
    public var lastReservoirValue: LastReservoirValue?
    public var historicalGlucose: [HistoricalGlucoseValue]?
    public var originalCarbEntry: StoredCarbEntry?
    public var carbEntry: StoredCarbEntry?
    public var manualGlucoseSample: StoredGlucoseSample?
    public var carbsOnBoard: CarbValue?
    public var insulinOnBoard: InsulinValue?
    public var glucoseTargetRangeSchedule: GlucoseRangeSchedule?
    public var predictedGlucose: [PredictedGlucoseValue]?
    public var automaticDoseRecommendation: AutomaticDoseRecommendation?
    public var manualBolusRecommendation: ManualBolusRecommendationWithDate?
    public var manualBolusRequested: Double?
    public var warnings: [Issue]
    public var errors: [Issue]
    public var syncIdentifier: UUID

    public init(date: Date = Date(),
                controllerTimeZone: TimeZone = TimeZone.current,
                reason: String,
                settings: Settings? = nil,
                scheduleOverride: TemporaryScheduleOverride? = nil,
                controllerStatus: ControllerStatus? = nil,
                pumpManagerStatus: PumpManagerStatus? = nil,
                pumpStatusHighlight: StoredDeviceHighlight? = nil,
                cgmManagerStatus: CGMManagerStatus? = nil,
                lastReservoirValue: LastReservoirValue? = nil,
                historicalGlucose: [HistoricalGlucoseValue]? = nil,
                originalCarbEntry: StoredCarbEntry? = nil,
                carbEntry: StoredCarbEntry? = nil,
                manualGlucoseSample: StoredGlucoseSample? = nil,
                carbsOnBoard: CarbValue? = nil,
                insulinOnBoard: InsulinValue? = nil,
                glucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
                predictedGlucose: [PredictedGlucoseValue]? = nil,
                automaticDoseRecommendation: AutomaticDoseRecommendation? = nil,
                manualBolusRecommendation: ManualBolusRecommendationWithDate? = nil,
                manualBolusRequested: Double? = nil,
                warnings: [Issue] = [],
                errors: [Issue] = [],
                syncIdentifier: UUID = UUID()) {
        self.date = date
        self.controllerTimeZone = controllerTimeZone
        self.reason = reason
        self.settings = settings
        self.scheduleOverride = scheduleOverride
        self.controllerStatus = controllerStatus
        self.pumpManagerStatus = pumpManagerStatus
        self.pumpStatusHighlight = pumpStatusHighlight
        self.cgmManagerStatus = cgmManagerStatus
        self.lastReservoirValue = lastReservoirValue
        self.historicalGlucose = historicalGlucose
        self.originalCarbEntry = originalCarbEntry
        self.carbEntry = carbEntry
        self.manualGlucoseSample = manualGlucoseSample
        self.carbsOnBoard = carbsOnBoard
        self.insulinOnBoard = insulinOnBoard
        self.glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        self.predictedGlucose = predictedGlucose
        self.automaticDoseRecommendation = automaticDoseRecommendation
        self.manualBolusRecommendation = manualBolusRecommendation
        self.manualBolusRequested = manualBolusRequested
        self.warnings = warnings
        self.errors = errors
        self.syncIdentifier = syncIdentifier
    }

    public struct Settings: Codable, Equatable {
        public let syncIdentifier: UUID

        public init(syncIdentifier: UUID) {
            self.syncIdentifier = syncIdentifier
        }
    }

    public struct ControllerStatus: Codable, Equatable {
        public enum BatteryState: String, Codable {
            case unknown
            case unplugged
            case charging
            case full
        }

        public let batteryState: BatteryState?
        public let batteryLevel: Float?

        public init(batteryState: BatteryState? = nil, batteryLevel: Float? = nil) {
            self.batteryState = batteryState
            self.batteryLevel = batteryLevel
        }
    }

    public struct LastReservoirValue: Codable {
        public let startDate: Date
        public let unitVolume: Double

        public init(startDate: Date, unitVolume: Double) {
            self.startDate = startDate
            self.unitVolume = unitVolume
        }
    }

    public struct Issue: Codable, Equatable {
        public let id: String
        public let details: [String: String]?

        public init(id: String, details: [String: String]? = nil) {
            self.id = id
            self.details = details?.isEmpty == false ? details : nil
        }
    }

    public struct StoredDeviceHighlight: Codable, Equatable, DeviceStatusHighlight {
        public var localizedMessage: String
        public var imageName: String
        public var state: DeviceStatusHighlightState

        public init(localizedMessage: String, imageName: String, state: DeviceStatusHighlightState) {
            self.localizedMessage = localizedMessage
            self.imageName = imageName
            self.state = state
        }
    }
}

public struct ManualBolusRecommendationWithDate: Codable {
    public let recommendation: ManualBolusRecommendation
    public let date: Date

    public init(recommendation: ManualBolusRecommendation, date: Date) {
        self.recommendation = recommendation
        self.date = date
    }
}

extension StoredDosingDecision: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(date: try container.decode(Date.self, forKey: .date),
                  controllerTimeZone: try container.decode(TimeZone.self, forKey: .controllerTimeZone),
                  reason: try container.decode(String.self, forKey: .reason),
                  settings: try container.decodeIfPresent(Settings.self, forKey: .settings),
                  scheduleOverride: try container.decodeIfPresent(TemporaryScheduleOverride.self, forKey: .scheduleOverride),
                  controllerStatus: try container.decodeIfPresent(ControllerStatus.self, forKey: .controllerStatus),
                  pumpManagerStatus: try container.decodeIfPresent(PumpManagerStatus.self, forKey: .pumpManagerStatus),
                  pumpStatusHighlight: try container.decodeIfPresent(StoredDeviceHighlight.self, forKey: .pumpStatusHighlight),
                  cgmManagerStatus: try container.decodeIfPresent(CGMManagerStatus.self, forKey: .cgmManagerStatus),
                  lastReservoirValue: try container.decodeIfPresent(LastReservoirValue.self, forKey: .lastReservoirValue),
                  historicalGlucose: try container.decodeIfPresent([HistoricalGlucoseValue].self, forKey: .historicalGlucose),
                  originalCarbEntry: try container.decodeIfPresent(StoredCarbEntry.self, forKey: .originalCarbEntry),
                  carbEntry: try container.decodeIfPresent(StoredCarbEntry.self, forKey: .carbEntry),
                  manualGlucoseSample: try container.decodeIfPresent(StoredGlucoseSample.self, forKey: .manualGlucoseSample),
                  carbsOnBoard: try container.decodeIfPresent(CarbValue.self, forKey: .carbsOnBoard),
                  insulinOnBoard: try container.decodeIfPresent(InsulinValue.self, forKey: .insulinOnBoard),
                  glucoseTargetRangeSchedule: try container.decodeIfPresent(GlucoseRangeSchedule.self, forKey: .glucoseTargetRangeSchedule),
                  predictedGlucose: try container.decodeIfPresent([PredictedGlucoseValue].self, forKey: .predictedGlucose),
                  automaticDoseRecommendation: try container.decodeIfPresent(AutomaticDoseRecommendation.self, forKey: .automaticDoseRecommendation),
                  manualBolusRecommendation: try container.decodeIfPresent(ManualBolusRecommendationWithDate.self, forKey: .manualBolusRecommendation),
                  manualBolusRequested: try container.decodeIfPresent(Double.self, forKey: .manualBolusRequested),
                  warnings: try container.decodeIfPresent([Issue].self, forKey: .warnings) ?? [],
                  errors: try container.decodeIfPresent([Issue].self, forKey: .errors) ?? [],
                  syncIdentifier: try container.decode(UUID.self, forKey: .syncIdentifier))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(controllerTimeZone, forKey: .controllerTimeZone)
        try container.encode(reason, forKey: .reason)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encodeIfPresent(scheduleOverride, forKey: .scheduleOverride)
        try container.encodeIfPresent(controllerStatus, forKey: .controllerStatus)
        try container.encodeIfPresent(pumpManagerStatus, forKey: .pumpManagerStatus)
        try container.encodeIfPresent(pumpStatusHighlight, forKey: .pumpStatusHighlight)
        try container.encodeIfPresent(cgmManagerStatus, forKey: .cgmManagerStatus)
        try container.encodeIfPresent(lastReservoirValue, forKey: .lastReservoirValue)
        try container.encodeIfPresent(historicalGlucose, forKey: .historicalGlucose)
        try container.encodeIfPresent(originalCarbEntry, forKey: .originalCarbEntry)
        try container.encodeIfPresent(carbEntry, forKey: .carbEntry)
        try container.encodeIfPresent(manualGlucoseSample, forKey: .manualGlucoseSample)
        try container.encodeIfPresent(carbsOnBoard, forKey: .carbsOnBoard)
        try container.encodeIfPresent(insulinOnBoard, forKey: .insulinOnBoard)
        try container.encodeIfPresent(glucoseTargetRangeSchedule, forKey: .glucoseTargetRangeSchedule)
        try container.encodeIfPresent(predictedGlucose, forKey: .predictedGlucose)
        try container.encodeIfPresent(automaticDoseRecommendation, forKey: .automaticDoseRecommendation)
        try container.encodeIfPresent(manualBolusRecommendation, forKey: .manualBolusRecommendation)
        try container.encodeIfPresent(manualBolusRequested, forKey: .manualBolusRequested)
        try container.encodeIfPresent(!warnings.isEmpty ? warnings : nil, forKey: .warnings)
        try container.encodeIfPresent(!errors.isEmpty ? errors : nil, forKey: .errors)
        try container.encode(syncIdentifier, forKey: .syncIdentifier)
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case controllerTimeZone
        case reason
        case settings
        case scheduleOverride
        case controllerStatus
        case pumpManagerStatus
        case pumpStatusHighlight
        case cgmManagerStatus
        case lastReservoirValue
        case historicalGlucose
        case originalCarbEntry
        case carbEntry
        case manualGlucoseSample
        case carbsOnBoard
        case insulinOnBoard
        case glucoseTargetRangeSchedule
        case predictedGlucose
        case automaticDoseRecommendation
        case manualBolusRecommendation
        case manualBolusRequested
        case warnings
        case errors
        case syncIdentifier
    }
}

// MARK: - Critical Event Log Export

extension DosingDecisionStore: CriticalEventLog {
    private var exportProgressUnitCountPerObject: Int64 { 33 }
    private var exportFetchLimit: Int { Int(criticalEventLogExportProgressUnitCountPerFetch / exportProgressUnitCountPerObject) }

    public var exportName: String { "DosingDecisions.json" }

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

extension DosingDecisionStore {
    public func addStoredDosingDecisions(dosingDecisions: [StoredDosingDecision], completion: @escaping (Error?) -> Void) {
        guard !dosingDecisions.isEmpty else {
            completion(nil)
            return
        }

        dataAccessQueue.async {
            var error: Error?

            self.store.managedObjectContext.performAndWait {
                for dosingDecision in dosingDecisions {
                    guard let data = self.encodeDosingDecision(dosingDecision) else {
                        continue
                    }
                    let object = DosingDecisionObject(context: self.store.managedObjectContext)
                    object.data = data
                    object.date = dosingDecision.date
                }
                error = self.store.save()
            }

            guard error == nil else {
                completion(error)
                return
            }

            self.log.info("Added %d DosingDecisionObjects", dosingDecisions.count)
            self.delegate?.dosingDecisionStoreHasUpdatedDosingDecisionData(self)
            completion(nil)
        }
    }
}
