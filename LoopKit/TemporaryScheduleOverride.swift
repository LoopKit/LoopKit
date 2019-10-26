//
//  TemporaryScheduleOverride.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/1/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


public struct TemporaryScheduleOverride: Hashable {
    public enum Context: Hashable {
        case preMeal
        case legacyWorkout
        case preset(TemporaryScheduleOverridePreset)
        case custom
    }
    
    public enum EnactTrigger: Hashable {
        case local
        case remote(String)
    }

    public enum Duration: Hashable, Comparable {
        case finite(TimeInterval)
        case indefinite

        public var timeInterval: TimeInterval {
            switch self {
            case .finite(let interval):
                return interval
            case .indefinite:
                return .infinity
            }
        }

        public var isFinite: Bool {
            return timeInterval.isFinite
        }

        public static func < (lhs: Duration, rhs: Duration) -> Bool {
            return lhs.timeInterval < rhs.timeInterval
        }
    }

    public var context: Context
    public var settings: TemporaryScheduleOverrideSettings
    public var startDate: Date
    public let syncIdentifier: UUID
    public let enactTrigger: EnactTrigger

    public var duration: Duration {
        didSet {
            precondition(duration.timeInterval > 0)
        }
    }

    public var endDate: Date {
        get {
            return startDate + duration.timeInterval
        }
        set {
            precondition(newValue > startDate)
            if newValue == .distantFuture {
                duration = .indefinite
            } else {
                duration = .finite(newValue.timeIntervalSince(startDate))
            }
        }
    }

    public var activeInterval: DateInterval {
        get {
            return DateInterval(start: startDate, end: endDate)
        }
        set {
            startDate = newValue.start
            endDate = newValue.end
        }
    }

    public func hasFinished(relativeTo date: Date = Date()) -> Bool {
        return date > endDate
    }

    public init(context: Context, settings: TemporaryScheduleOverrideSettings, startDate: Date, duration: Duration, enactTrigger: EnactTrigger, syncIdentifier: UUID) {
        precondition(duration.timeInterval > 0)
        self.context = context
        self.settings = settings
        self.startDate = startDate
        self.duration = duration
        self.enactTrigger = enactTrigger
        self.syncIdentifier = syncIdentifier
    }
    
    public func isActive(at date: Date = Date()) -> Bool {
        return activeInterval.contains(date)
    }
}

extension TemporaryScheduleOverride: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let contextRawValue = rawValue["context"] as? Context.RawValue,
            let context = Context(rawValue: contextRawValue),
            let settingsRawValue = rawValue["settings"] as? TemporaryScheduleOverrideSettings.RawValue,
            let settings = TemporaryScheduleOverrideSettings(rawValue: settingsRawValue),
            let startDateSeconds = rawValue["startDate"] as? TimeInterval,
            let durationRawValue = rawValue["duration"] as? Duration.RawValue,
            let duration = Duration(rawValue: durationRawValue)
        else {
            return nil
        }
        
        let startDate = Date(timeIntervalSince1970: startDateSeconds)

        let syncIdentifier: UUID
        if let syncIdentifierRaw = rawValue["syncIdentifier"] as? String,
            let storedSyncIdentifier = UUID(uuidString: syncIdentifierRaw) {
            syncIdentifier = storedSyncIdentifier
        } else {
            syncIdentifier = UUID()
        }
        
        let enactTrigger: EnactTrigger
        if let enactTriggerRaw = rawValue["enactTrigger"] as? EnactTrigger.RawValue,
            let storedEnactTrigger = EnactTrigger(rawValue: enactTriggerRaw)
        {
            enactTrigger = storedEnactTrigger
        } else {
            enactTrigger = .local
        }
        
        self.init(context: context, settings: settings, startDate: startDate, duration: duration, enactTrigger: enactTrigger, syncIdentifier: syncIdentifier)
    }

    public var rawValue: RawValue {
        return [
            "context": context.rawValue,
            "settings": settings.rawValue,
            "startDate": startDate.timeIntervalSince1970,
            "duration": duration.rawValue,
            "syncIdentifier": syncIdentifier.uuidString,
        ]
    }
}

extension TemporaryScheduleOverride.Context: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let context = rawValue["context"] as? String else {
            return nil
        }

        switch context {
        case "premeal":
            self = .preMeal
        case "legacyWorkout":
            self = .legacyWorkout
        case "preset":
            guard
                let presetRawValue = rawValue["preset"] as? TemporaryScheduleOverridePreset.RawValue,
                let preset = TemporaryScheduleOverridePreset(rawValue: presetRawValue)
            else {
                return nil
            }
            self = .preset(preset)
        case "custom":
            self = .custom
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .preMeal:
            return ["context": "premeal"]
        case .legacyWorkout:
            return ["context": "legacyWorkout"]
        case .preset(let preset):
            return [
                "context": "preset",
                "preset": preset.rawValue
            ]
        case .custom:
            return ["context": "custom"]
        }
    }
}

extension TemporaryScheduleOverride.Duration: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let duration = rawValue["duration"] as? String else {
            return nil
        }

        switch duration {
        case "finite":
            guard let interval = rawValue["interval"] as? TimeInterval else {
                return nil
            }
            self = .finite(interval)
        case "indefinite":
            self = .indefinite
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .finite(let interval):
            return [
                "duration": "finite",
                "interval": interval
            ]
        case .indefinite:
            return ["duration": "indefinite"]
        }
    }
}

extension TemporaryScheduleOverride.EnactTrigger: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let trigger = rawValue["trigger"] as? String else {
            return nil
        }
        
        switch trigger {
        case "local":
            self = .local
        case "remote":
            guard let remoteAddress = rawValue["remoteAddress"] as? String else {
                return nil
            }
            self = .remote(remoteAddress)
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .local:
            return ["trigger": "local"]
        case .remote(let remoteAddress):
            return [
                "trigger": "remote",
                "remoteAddress": remoteAddress
            ]
        }
    }
}

