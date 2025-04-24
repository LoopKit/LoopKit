//
//  TemporaryPreset.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public struct PresetScheduleRepeatOptions: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8

    public static let none = PresetScheduleRepeatOptions([])
    public static let sunday = PresetScheduleRepeatOptions(rawValue: 1 << 0)
    public static let monday = PresetScheduleRepeatOptions(rawValue: 1 << 1)
    public static let tuesday = PresetScheduleRepeatOptions(rawValue: 1 << 2)
    public static let wednesday = PresetScheduleRepeatOptions(rawValue: 1 << 3)
    public static let thursday = PresetScheduleRepeatOptions(rawValue: 1 << 4)
    public static let friday = PresetScheduleRepeatOptions(rawValue: 1 << 5)
    public static let saturday = PresetScheduleRepeatOptions(rawValue: 1 << 6)

    public static let allCases: [PresetScheduleRepeatOptions] = [
        .sunday,
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
    ]

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    // Helper to map OptionSet to calendar weekday index (Sunday = 1 in Calendar)
    public var calendarWeekdayIndex: Int? {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        default: return nil
        }
    }
}

extension PresetScheduleRepeatOptions: Codable {}

public struct TemporaryPreset: Hashable, Sendable {
    public let id: UUID
    public var symbol: String
    public var name: String
    public var settings: TemporaryPresetSettings
    public var duration: TemporaryScheduleOverride.Duration
    public var scheduleStartDate: Date?
    public var repeatOptions: PresetScheduleRepeatOptions?

    public init(id: UUID = UUID(), symbol: String, name: String, settings: TemporaryPresetSettings, duration: TemporaryScheduleOverride.Duration, scheduleStartDate: Date? = nil, repeatOptions: PresetScheduleRepeatOptions = .none) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.settings = settings
        self.duration = duration
        self.scheduleStartDate = scheduleStartDate
        self.repeatOptions = repeatOptions
    }

    public func createOverride(enactTrigger: TemporaryScheduleOverride.EnactTrigger, beginningAt date: Date = Date()) -> TemporaryScheduleOverride {
        return TemporaryScheduleOverride(
            context: .preset(self),
            settings: settings,
            startDate: date,
            duration: duration,
            enactTrigger: enactTrigger,
            syncIdentifier: UUID()
        )
    }
}

extension TemporaryPreset: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let idString = rawValue["id"] as? String,
            let id = UUID(uuidString: idString),
            let symbol = rawValue["symbol"] as? String,
            let name = rawValue["name"] as? String,
            let settingsRawValue = rawValue["settings"] as? TemporaryPresetSettings.RawValue,
            let settings = TemporaryPresetSettings(rawValue: settingsRawValue),
            let durationRawValue = rawValue["duration"] as? TemporaryScheduleOverride.Duration.RawValue,
            let duration = TemporaryScheduleOverride.Duration(rawValue: durationRawValue)
        else {
            return nil
        }

        let scheduleStartDate = rawValue["scheduleStartDate"] as? Date
        let rawRepeatOptions = rawValue["repeatOptions"] as? PresetScheduleRepeatOptions.RawValue

        self.init(
            id: id,
            symbol: symbol,
            name: name,
            settings: settings,
            duration: duration,
            scheduleStartDate: scheduleStartDate,
            repeatOptions: rawRepeatOptions.flatMap(PresetScheduleRepeatOptions.init) ?? .none
        )
    }

    public var rawValue: RawValue {
        var rval: RawValue = [
            "id": id.uuidString,
            "symbol": symbol,
            "name": name,
            "settings": settings.rawValue,
            "duration": duration.rawValue
        ]

        if let scheduleStartDate {
            rval["scheduleStartDate"] = scheduleStartDate
        }

        if let repeatOptions {
            rval["repeatOptions"] = repeatOptions.rawValue
        }

        return rval
    }
}

extension TemporaryPreset: Codable {}
