//
//  CgmEvent.swift
//  LoopKit
//
//  Created by Pete Schwamb on 9/9/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation

public enum CgmEventType: String {
    case sensorStart
    case sensorEnd
    case transmitterStart
    case transmitterEnd
    case sensorIssue
}

public struct PersistedCgmEvent {
    public var date: Date
    public var type: CgmEventType
    public var deviceIdentifier: String
    public var expectedLifetime: TimeInterval?
    public var warmupPeriod: TimeInterval?
    public var failureMessage: String?

    public init(date: Date, type: CgmEventType, deviceIdentifier: String, expectedLifetime: TimeInterval? = nil, warmupPeriod: TimeInterval? = nil, failureMessage: String? = nil) {
        self.date = date
        self.type = type
        self.deviceIdentifier = deviceIdentifier
        self.expectedLifetime = expectedLifetime
        self.warmupPeriod = warmupPeriod
        self.failureMessage = failureMessage
    }

}

extension PersistedCgmEvent {
    init?(managedObject: CgmEvent) {
        guard let type = managedObject.type else {
            return nil
        }
        self.init(
            date: managedObject.date,
            type: type,
            deviceIdentifier: managedObject.deviceIdentifier,
            expectedLifetime: managedObject.expectedLifetime,
            warmupPeriod: managedObject.warmupPeriod,
            failureMessage: managedObject.failureMessage
        )
    }
}

extension CgmEvent {
    var persistedCgmEvent: PersistedCgmEvent? {
        return PersistedCgmEvent(managedObject: self)
    }
}

// MARK: - Sensor state reporting

/// What a single reading says about the sensor.
public enum CgmSensorObservation: Equatable {
    /// The reading carries glucose the kit itself considers reliable.
    case reliable
    /// The reading carries no reliable glucose; `state` is the kit's own name
    /// for the sensor state behind that.
    case unreliable(state: String)
}

/// Decides which sensor states become `CgmEventType.sensorIssue` events.
///
/// A state is reported when a reading carries no reliable glucose and the
/// state differs from the last one reported, so a persisting state is reported
/// once. A reliable reading or a new sensor session clears the log, so a state
/// that returns after recovery is reported again. The log outlives the manager
/// instance, so a relaunch during a persisting state stays quiet.
public enum CgmSensorStateReporter {
    private struct Log: Codable, Equatable {
        var sensorSessionStart: Date?
        var notedState: String?
    }

    private static let lock = NSLock()

    /// The event to hand to the CGM manager delegate, if this reading's state
    /// is due for a note.
    ///
    /// - Parameters:
    ///   - observation: What `date`'s reading says about the sensor.
    ///   - namespace: Distinguishes one CGM manager's log from another's.
    ///   - sensorSessionStart: Start of the session the reading belongs to.
    ///     A new session clears the log. Both Dexcom kits re-derive this from
    ///     the phone's clock on every reading, so it carries transport jitter
    ///     and is compared with a tolerance far below the gap between two real
    ///     sessions.
    ///   - deviceIdentifier: Sensor or transmitter identifier.
    ///   - date: Timestamp of the reading.
    public static func event(for observation: CgmSensorObservation,
                             namespace: String,
                             sensorSessionStart: Date?,
                             deviceIdentifier: String,
                             date: Date) -> PersistedCgmEvent?
    {
        lock.lock()
        defer { lock.unlock() }

        let key = "com.loopkit.LoopKit.CgmSensorStateReporter.\(namespace)"
        var log = (UserDefaults.standard.data(forKey: key).flatMap {
            try? JSONDecoder().decode(Log.self, from: $0)
        }) ?? Log()

        let previous = log

        if let sensorSessionStart = sensorSessionStart, isNewSession(sensorSessionStart, from: log.sensorSessionStart) {
            // The first date seen for a session is kept, so later readings
            // compare against a fixed point and the jitter cannot accumulate.
            log.sensorSessionStart = sensorSessionStart
            log.notedState = nil
        }

        var event: PersistedCgmEvent?

        switch observation {
        case .reliable:
            log.notedState = nil
        case .unreliable(let state):
            if state != log.notedState {
                log.notedState = state
                event = PersistedCgmEvent(date: date,
                                          type: .sensorIssue,
                                          deviceIdentifier: deviceIdentifier,
                                          failureMessage: "CGM: " + state)
            }
        }

        if log != previous, let data = try? JSONEncoder().encode(log) {
            UserDefaults.standard.set(data, forKey: key)
        }

        return event
    }

    /// Whether `sensorSessionStart` belongs to a session other than the one
    /// already being tracked.
    ///
    /// The tolerance absorbs the transport jitter both kits carry: each derived
    /// start is the true start plus the delay before the phone processed the
    /// message, so repeated readings of one session land within seconds of each
    /// other, while two real sessions are separated by at least a warmup.
    private static func isNewSession(_ sensorSessionStart: Date, from tracked: Date?) -> Bool {
        guard let tracked = tracked else {
            return true
        }
        return abs(sensorSessionStart.timeIntervalSince(tracked)) > .minutes(15)
    }
}
