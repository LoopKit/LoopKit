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
        
        public var isInfinite: Bool {
            return timeInterval.isInfinite
        }

        public static func < (lhs: Duration, rhs: Duration) -> Bool {
            return lhs.timeInterval < rhs.timeInterval
        }
    }

    public var context: Context
    public var settings: TemporaryScheduleOverrideSettings
    public var startDate: Date
    public let enactTrigger: EnactTrigger
    public let syncIdentifier: UUID
    
    public var actualEnd: End = .natural
    
    public var actualEndDate: Date {
        switch actualEnd {
        case .natural:
            return scheduledEndDate
        case .early(let endDate):
            return endDate
        case .deleted:
            return scheduledEndDate
        }
    }

    public var duration: Duration {
        didSet {
            precondition(duration.timeInterval > 0)
        }
    }

    public var scheduledEndDate: Date {
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
            return DateInterval(start: startDate, end: actualEndDate)
        }
        set {
            startDate = newValue.start
            scheduledEndDate = newValue.end
        }
    }

    public func hasFinished(relativeTo date: Date = Date()) -> Bool {
        return date > actualEndDate
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

        let enactTrigger: EnactTrigger
        if let enactTriggerRaw = rawValue["enactTrigger"] as? EnactTrigger.RawValue,
            let storedEnactTrigger = EnactTrigger(rawValue: enactTriggerRaw)
        {
            enactTrigger = storedEnactTrigger
        } else {
            enactTrigger = .local
        }

        let syncIdentifier: UUID
        if let syncIdentifierRaw = rawValue["syncIdentifier"] as? String,
            let storedSyncIdentifier = UUID(uuidString: syncIdentifierRaw) {
            syncIdentifier = storedSyncIdentifier
        } else {
            syncIdentifier = UUID()
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
            "enactTrigger": enactTrigger.rawValue,
        ]
    }
}

extension TemporaryScheduleOverride: Codable {}

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

extension TemporaryScheduleOverride.Context: Codable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            switch string {
            case CodableKeys.preMeal.rawValue:
                self = .preMeal
            case CodableKeys.legacyWorkout.rawValue:
                self = .legacyWorkout
            case CodableKeys.custom.rawValue:
                self = .custom
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodableKeys.self)
            if let preset = try container.decodeIfPresent(Preset.self, forKey: .preset) {
                self = .preset(preset.preset)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .preMeal:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.preMeal.rawValue)
        case .legacyWorkout:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.legacyWorkout.rawValue)
        case .preset(let preset):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(Preset(preset: preset), forKey: .preset)
        case .custom:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.custom.rawValue)
        }
    }

    private struct Preset: Codable {
        let preset: TemporaryScheduleOverridePreset
    }

    private enum CodableKeys: String, CodingKey {
        case preMeal
        case legacyWorkout
        case preset
        case custom
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

extension TemporaryScheduleOverride.Duration: Codable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            switch string {
            case CodableKeys.indefinite.rawValue:
                self = .indefinite
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodableKeys.self)
            if let finite = try container.decodeIfPresent(Finite.self, forKey: .finite) {
                self = .finite(finite.duration)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .finite(let duration):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(Finite(duration: duration), forKey: .finite)
        case .indefinite:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.indefinite.rawValue)
        }
    }

    private struct Finite: Codable {
        let duration: TimeInterval
    }

    private enum CodableKeys: String, CodingKey {
        case finite
        case indefinite
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

extension TemporaryScheduleOverride.EnactTrigger: Codable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            switch string {
            case CodableKeys.local.rawValue:
                self = .local
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodableKeys.self)
            if let remote = try container.decodeIfPresent(Remote.self, forKey: .remote) {
                self = .remote(remote.address)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .local:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.local.rawValue)
        case .remote(let address):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(Remote(address: address), forKey: .remote)
        }
    }

    private struct Remote: Codable {
        let address: String
    }

    private enum CodableKeys: String, CodingKey {
        case local
        case remote
    }
}
