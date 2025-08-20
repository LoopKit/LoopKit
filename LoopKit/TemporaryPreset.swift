//
//  TemporaryPreset.swift
//  Loop
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import UIKit

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

public struct PresetSymbol: Hashable, Sendable, Codable, RawRepresentable, ExpressibleByStringLiteral {
    public enum SymbolType: String, Sendable, Codable {
        case emoji
        case systemImage
        case image
    }
    
    public enum SymbolTint: String, Sendable, Codable {
        case preMeal
    }
    
    public let symbolType: SymbolType
    public let tint: SymbolTint?
    public let value: String
    
    public var rawValue: [String: Any?] {
        var rawValue: [String: Any?] = [
            "symbolType": symbolType.rawValue,
            "value": value
        ]
        
        if let tint {
            rawValue["tint"] = tint.rawValue
        }
        
        return rawValue
    }
    
    public init(stringLiteral value: StringLiteralType) {
        self = .emoji(value)
    }
    
    public static func emoji(_ emojiString: String) -> PresetSymbol {
        .init(emoji: emojiString)
    }
    
    public static func image(_ imageName: String, tint: SymbolTint? = nil) -> PresetSymbol {
        .init(symbolType: .image, tint: tint, value: imageName)
    }
    
    public static func systemImage(_ systemName: String, tint: SymbolTint? = nil) -> PresetSymbol {
        .init(symbolType: .systemImage, tint: tint, value: systemName)
    }

    private init(emoji: String) {
        self.symbolType = .emoji
        self.tint = nil
        self.value = emoji
    }
    
    public init(symbolType: SymbolType, tint: SymbolTint? = nil, value: String) {
        self.symbolType = symbolType
        self.tint = tint
        self.value = value
    }
    
    enum CodingKeys: String, CodingKey {
        case symbolType
        case tint
        case value
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let symbolTypeValue = try container.decodeIfPresent(SymbolType.self, forKey: .symbolType) {
            self.symbolType = symbolTypeValue
            self.tint = try container.decodeIfPresent(SymbolTint.self, forKey: .tint)
            self.value = try container.decode(String.self, forKey: .value)
        } else {
            self.symbolType = .emoji
            self.tint = nil
            self.value = try container.decode(String.self, forKey: .symbolType)
        }
    }
    
    public init?(rawValue: [String : Any?]) {
        guard let symbolTypeRawValue = rawValue["symbolType"] as? SymbolType.RawValue,
              let symbolType = SymbolType(rawValue: symbolTypeRawValue),
              let symbolTintRawValue = rawValue["tint"] as? SymbolTint.RawValue,
              let symbolTint = SymbolTint(rawValue: symbolTintRawValue),
              let value = rawValue["value"] as? String else {
            return nil
        }
        
        self.symbolType = symbolType
        self.tint = symbolTint
        self.value = value
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbolType, forKey: .symbolType)
        try container.encode(tint, forKey: .tint)
        try container.encode(value, forKey: .value)
    }
    
    public var textualRepresentation: NSAttributedString? {
        let attachment = NSTextAttachment()
        
        switch symbolType {
        case .emoji:
            return NSAttributedString(string: value)
        case .image, .systemImage:
            attachment.image = UIImage(systemName: value)
            return NSAttributedString(attachment: attachment)
        }
    }
}

public struct TemporaryPreset: Hashable, Sendable {
    public let id: String
    public var symbol: PresetSymbol?
    public var name: String
    public var settings: TemporaryPresetSettings
    public var duration: TemporaryScheduleOverride.Duration
    public var scheduleStartDate: Date?
    public var repeatOptions: PresetScheduleRepeatOptions?

    public init(id: String = UUID().uuidString, symbol: PresetSymbol?, name: String, settings: TemporaryPresetSettings, duration: TemporaryScheduleOverride.Duration, scheduleStartDate: Date? = nil, repeatOptions: PresetScheduleRepeatOptions = .none) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.settings = settings
        self.duration = duration
        self.scheduleStartDate = scheduleStartDate
        self.repeatOptions = repeatOptions
    }

    public func nextScheduledStartAfter(_ date: Date, calendar: Calendar = .current) -> Date? {
        guard let scheduleStartDate = scheduleStartDate else { return nil }

        // If no repeat options are set, this is a one-time preset
        guard let repeatOptions = repeatOptions, repeatOptions != .none else {
            // For one-time presets, return the schedule start date only if it's after the given date
            return scheduleStartDate > date ? scheduleStartDate : nil
        }

        // Get the time components from the original schedule start date
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: scheduleStartDate)

        let startDate = calendar.startOfDay(for: date)

        // Look ahead up to 7 days (including today) to find the next occurrence
        for dayOffset in 0..<8 {
            let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) ?? startDate
            let weekday = calendar.component(.weekday, from: checkDate)

            // Check if this weekday matches any of the repeat options
            for repeatOption in PresetScheduleRepeatOptions.allCases {
                if repeatOptions.contains(repeatOption),
                   let optionWeekday = repeatOption.calendarWeekdayIndex,
                   weekday == optionWeekday {

                    // Create the full date with the original time components
                    var fullDateComponents = calendar.dateComponents([.year, .month, .day], from: checkDate)
                    fullDateComponents.hour = timeComponents.hour
                    fullDateComponents.minute = timeComponents.minute
                    fullDateComponents.second = timeComponents.second

                    if let scheduledDate = calendar.date(from: fullDateComponents),
                       scheduledDate > date {
                        return scheduledDate
                    }
                }
            }
        }

        return nil
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
        
        var symbol: PresetSymbol? = nil
        if let symbolRawValue = rawValue["symbol"] as? PresetSymbol.RawValue {
            symbol = PresetSymbol(rawValue: symbolRawValue)
        } else if let symbolRawValueString = rawValue["symbol"] as? String {
            symbol = .emoji(symbolRawValueString)
        }
        
        self.init(
            id: idString,
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
            "id": id,
            "name": name,
            "settings": settings.rawValue,
            "duration": duration.rawValue
        ]
        
        if let symbol {
            rval["symbol"] = symbol.rawValue
        }

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
