//
//  BolusOriginStore.swift
//  LoopKit
//
//  Correlates a bolus request with the dose the pump later reports, so a caller (the app) can record where a
//  bolus came from and a consumer (e.g. a remote-data service) can read it back. Lives in LoopKit so both the
//  app and in-process service plugins can share one instance; it is file-backed so the mapping survives an app
//  restart while a bolus is in flight.
//
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import Foundation
import os.log

/// Where a user-initiated bolus came from. Autobolus / SMB is intentionally absent — that is already conveyed
/// by the dose's `automatic` flag (and, in Trio, the SMB event type). `rawValue` is the machine token uploaded
/// to Nightscout; `displayName` is the human label. Not every app uses every case (e.g. Loop has no bolus
/// shortcut), which is fine.
public enum BolusOrigin: String, Codable {
    case remote
    case watch
    case manual
    case shortcut

    public var displayName: String {
        switch self {
        case .remote: return "Remote"
        case .watch: return "Watch"
        case .manual: return "Manual"
        case .shortcut: return "Shortcut"
        }
    }
}

public final class BolusOriginStore {
    public static let shared = BolusOriginStore()

    private struct Entry: Codable {
        let origin: BolusOrigin
        let createdAt: Date
    }

    private let log = OSLog(category: "BolusOriginStore")
    private let lock = NSLock()

    /// Entries are keyed by either a request reference's `uuidString` or a reported dose's `syncIdentifier`
    /// (after promotion). The two key kinds share one dictionary on purpose: a key is only ever written and
    /// read as one kind, and a pump's syncIdentifier colliding with a caller-minted UUID string is not a
    /// realistic concern.
    private var entries: [String: Entry]

    /// In-flight references are short-lived; drop anything older than this so the file stays bounded.
    /// Expiry is applied when the store is loaded and whenever it is persisted — deliberately not on lookup,
    /// so a dose that surfaces late (e.g. resolved after prolonged uncertain delivery) still gets its origin
    /// if the entry happens to survive.
    private static let maxAge: TimeInterval = 6 * 60 * 60

    private let fileURL: URL?

    public init(fileURL: URL? = BolusOriginStore.defaultFileURL) {
        self.fileURL = fileURL
        var loaded: [String: Entry] = [:]
        if let fileURL = fileURL, let data = try? Data(contentsOf: fileURL) {
            do {
                loaded = try JSONDecoder().decode([String: Entry].self, from: data)
            } catch {
                OSLog(category: "BolusOriginStore").error("Discarding unreadable bolus origin file: %{public}@", String(describing: error))
            }
        }
        let cutoff = Date().addingTimeInterval(-Self.maxAge)
        entries = loaded.filter { $0.value.createdAt > cutoff }
    }

    public static var defaultFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("bolus_origins.json")
    }

    /// Remember an origin under a freshly generated reference and return the reference to pass to the pump.
    public func makeReference(for origin: BolusOrigin) -> UUID {
        let reference = UUID()
        sync {
            entries[reference.uuidString] = Entry(origin: origin, createdAt: Date())
            persist()
        }
        return reference
    }

    /// When the reported dose is known, re-key the origin from its request reference to the pump's stable
    /// `syncIdentifier`, which is what persists in the dose store and is available at upload time.
    public func promoteReference(_ reference: UUID, toSyncIdentifier syncIdentifier: String) {
        sync {
            guard let entry = entries.removeValue(forKey: reference.uuidString) else { return }
            entries[syncIdentifier] = entry
            persist()
        }
    }

    /// Resolve the origin recorded for a reported dose's `syncIdentifier`, if any.
    public func origin(forSyncIdentifier syncIdentifier: String) -> BolusOrigin? {
        sync { entries[syncIdentifier]?.origin }
    }

    /// Resolve the origin directly by its request reference. Use this when the reference is still available on
    /// the reported dose (no `syncIdentifier` promotion needed).
    public func origin(forReference reference: UUID) -> BolusOrigin? {
        sync { entries[reference.uuidString]?.origin }
    }

    /// Drop a mapping once it has been consumed, or clean up a request that failed.
    public func remove(reference: UUID) {
        sync { entries.removeValue(forKey: reference.uuidString); persist() }
    }

    public func remove(syncIdentifier: String) {
        sync { entries.removeValue(forKey: syncIdentifier); persist() }
    }

    // MARK: - Helpers

    @discardableResult private func sync<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    /// Caller must hold `lock`.
    private func persist() {
        let cutoff = Date().addingTimeInterval(-Self.maxAge)
        entries = entries.filter { $0.value.createdAt > cutoff }
        guard let fileURL = fileURL else { return }
        do {
            try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
        } catch {
            log.error("Failed to persist bolus origins: %{public}@", String(describing: error))
        }
    }
}
