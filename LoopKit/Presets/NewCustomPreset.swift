//
//  NewCustomPreset.swift
//  Loop
//
//  Created by Pete Schwamb on 2/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import UIKit

extension PresetScheduleRepeatOptions: CustomStringConvertible {
    public var description: String {
        let calendar = Calendar.current
        let weekdaySymbols = calendar.weekdaySymbols

        // Handle single day case
        if let weekdayIndex = calendarWeekdayIndex {
            return weekdaySymbols[weekdayIndex - 1] // -1 because array is 0-based
        }

        // Handle multiple days
        return NSLocalizedString("multiple days", comment: "Preset schedule repeat option multiple days")
    }

    public var veryShortDescription: String {
        let calendar = Calendar.current
        let weekdaySymbols = calendar.veryShortWeekdaySymbols

        // Handle single day case
        if let weekdayIndex = calendarWeekdayIndex {
            return weekdaySymbols[weekdayIndex - 1] // -1 because array is 0-based
        }

        // Handle multiple days
        return NSLocalizedString("Multiple", comment: "Preset schedule repeat option multiple days")
    }
}

public struct NewCustomPreset {
    public var savePreset: Bool
    public var insulinMultiplier: Double = 1
    public var correctionRange: ClosedRange<LoopQuantity>?
    public var name: String = ""
    public var duration: PresetDuration?
    public var startDate: Date?
    public var repeatOptions: PresetScheduleRepeatOptions

    public init(
        savePreset: Bool = true,
        insulinMultiplier: Double = 1,
        correctionRange: ClosedRange<LoopQuantity>? = nil,
        name: String = "",
        duration: PresetDuration? = nil,
        startDate: Date? = nil,
        repeatOptions: PresetScheduleRepeatOptions = .none
    ) {
        self.savePreset = savePreset
        self.insulinMultiplier = insulinMultiplier
        self.correctionRange = correctionRange
        self.name = name
        self.duration = duration
        self.startDate = startDate
        self.repeatOptions = repeatOptions
    }

    public var veryHighInsulinNeeds: Bool {
        return TemporaryScheduleOverride.isInMitigationRange(insulinNeedsScaleFactor: insulinMultiplier)
    }
}

public extension NewCustomPreset {
    func scheduleDescription() -> String {
        guard let startDate = startDate, !repeatOptions.isEmpty else {
            return ""
        }

        // Get date formatter for time (will use user's locale)
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short // Uses locale-appropriate short time format (e.g., "10:00 AM" or "10:00")
        let timeString = timeFormatter.string(from: startDate)

        // Get all selected days
        let selectedDays = PresetScheduleRepeatOptions.allCases
            .filter { repeatOptions.contains($0) }
            .map { $0.description } // Already localized via your existing description

        // Format the days string based on count
        let daysString: String
        switch selectedDays.count {
        case 1:
            daysString = selectedDays[0]
        case 2:
            daysString = String(
                format: NSLocalizedString("%@ and %@", comment: "Format for two days"),
                selectedDays[0],
                selectedDays[1]
            )
        default:
            let lastDay = selectedDays.last ?? ""
            let otherDays = selectedDays.dropLast().joined(separator: NSLocalizedString(", ", comment: "Separator for multiple days"))
            daysString = String(
                format: NSLocalizedString("%@, and %@", comment: "Format for three or more days"),
                otherDays,
                lastDay
            )
        }

        // Combine with localized format string
        return String(
            format: NSLocalizedString("Repeats weekly on %@ at %@", comment: "Weekly repeat schedule format"),
            daysString,
            timeString
        )
    }
}

public extension NewCustomPreset {
    var temporaryPreset: TemporaryPreset? {
        guard let duration else {
            return nil
        }
        let overrideDuration = duration.presetDuration

        let settings = TemporaryPresetSettings(
            targetRange: correctionRange,
            insulinNeedsScaleFactor: insulinMultiplier
        )
        
        let split = name.splitSymbolAndTitle()
        var symbol: PresetSymbol? = nil
        if let emoji = split.emoji {
            symbol = .emoji(emoji)
        }

        return TemporaryPreset(
            symbol: symbol,
            name: split.name,
            settings: settings,
            duration: overrideDuration,
            scheduleStartDate: startDate,
            repeatOptions: repeatOptions
        )
    }
}

private extension String {
    func splitSymbolAndTitle() -> (emoji: String?, name: String) {
        let trimmed = trimmingCharacters(in: .whitespaces)
        if let first = trimmed.first, first.isEmoji {
            let name = String(dropFirst()).trimmingCharacters(in: .whitespaces)
            return (emoji: String(first), name: name)
        } else {
            return (emoji: nil, name: trimmed)
        }
    }
}
