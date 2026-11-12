//
//  DoseMetadataStore.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import os.log
import Foundation
import CoreData

/// What Loop knows about a dose it sent to the pump. Pump managers never see it: they carry only
/// the `doseId` and return it on the `DoseEntry` they report, and Loop then sets `DoseEntry.metadata`.
public struct DoseMetadata: Codable, Hashable {
    public enum Origin: String, Codable {
        /// Loop's automatic dosing
        case automatic
        /// The person, in Loop's UI
        case user
        /// A remote command from a service
        case remote
    }

    public enum Device: String, Codable {
        case phone
        case watch
    }

    public var origin: Origin
    public var device: Device?
    /// The dosing decision the dose was enacted from
    public var decisionId: UUID?
    public var activationType: BolusActivationType?

    public init(origin: Origin, device: Device? = nil, decisionId: UUID? = nil, activationType: BolusActivationType? = nil) {
        self.origin = origin
        self.device = device
        self.decisionId = decisionId
        self.activationType = activationType
    }
}

extension DoseMetadata {
    private static let encoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }()

    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    init(encoded data: Data) throws {
        self = try PropertyListDecoder().decode(DoseMetadata.self, from: data)
    }
}

class DoseMetadataObject: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DoseMetadataObject> {
        return NSFetchRequest<DoseMetadataObject>(entityName: "DoseMetadataObject")
    }

    @NSManaged var doseId: UUID
    @NSManaged var date: Date
    @NSManaged var data: Data
}

/// Holds the metadata of doses Loop has sent until the pump reports them, across relaunches.
public class DoseMetadataStore {
    private let store: PersistenceController
    private let expireAfter: TimeInterval
    private let log = OSLog(category: "DoseMetadataStore")

    public init(store: PersistenceController, expireAfter: TimeInterval) {
        self.store = store
        self.expireAfter = expireAfter
    }

    /// Stores the metadata for a dose. Call before sending the dose to the pump, so a dose reported after a relaunch still finds it.
    public func storeMetadata(_ metadata: DoseMetadata, for doseId: UUID, date: Date = Date()) async throws {
        try await store.waitUntilReady()
        let data = try metadata.encoded()

        try await store.managedObjectContext.perform {
            let object = DoseMetadataObject(context: self.store.managedObjectContext)
            object.doseId = doseId
            object.date = date
            object.data = data
            if let error = self.store.save() {
                throw error
            }
        }

        await purgeExpiredMetadata()
    }

    public func metadata(for doseId: UUID) async throws -> DoseMetadata? {
        try await metadata(for: [doseId])[doseId]
    }

    public func metadata(for doseIds: [UUID]) async throws -> [UUID: DoseMetadata] {
        guard !doseIds.isEmpty else {
            return [:]
        }
        try await store.waitUntilReady()

        return try await store.managedObjectContext.perform {
            let request: NSFetchRequest<DoseMetadataObject> = DoseMetadataObject.fetchRequest()
            request.predicate = NSPredicate(format: "doseId IN %@", doseIds)

            var result: [UUID: DoseMetadata] = [:]
            for object in try self.store.managedObjectContext.fetch(request) {
                do {
                    result[object.doseId] = try DoseMetadata(encoded: object.data)
                } catch {
                    self.log.error("Unable to decode metadata for dose %{public}@: %{public}@", object.doseId.uuidString, String(describing: error))
                }
            }
            return result
        }
    }

    /// The events with each dose's metadata set, looked up by its doseId. A pump can report a dose
    /// several times before it is final, so the metadata is kept until it expires.
    public func addingMetadata(to events: [NewPumpEvent]) async -> [NewPumpEvent] {
        let doseIds = events.compactMap { $0.dose?.doseId }
        let metadata: [UUID: DoseMetadata]
        do {
            metadata = try await self.metadata(for: doseIds)
        } catch {
            log.error("Unable to read dose metadata: %{public}@", String(describing: error))
            return events
        }

        return events.map { event in
            guard var dose = event.dose, let doseId = dose.doseId, let doseMetadata = metadata[doseId] else {
                return event
            }
            dose.metadata = doseMetadata
            return NewPumpEvent(date: event.date, dose: dose, raw: event.raw, title: event.title, type: event.type, alarmType: event.alarmType)
        }
    }

    public func purgeMetadata(before date: Date) async throws {
        try await store.managedObjectContext.perform {
            let count = try self.store.managedObjectContext.purgeObjects(of: DoseMetadataObject.self, matching: NSPredicate(format: "date < %@", date as NSDate))
            self.log.info("Purged %d DoseMetadataObjects", count)
        }
    }

    private func purgeExpiredMetadata() async {
        do {
            try await purgeMetadata(before: Date(timeIntervalSinceNow: -expireAfter))
        } catch {
            log.error("Unable to purge DoseMetadataObjects: %{public}@", String(describing: error))
        }
    }
}
