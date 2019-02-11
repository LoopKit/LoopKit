//
//  TemporaryScheduleOverride.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/1/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit


public struct TemporaryScheduleOverride: Equatable {
    public enum Context: Equatable {
        case preMeal
        case preset(TemporaryScheduleOverridePreset)
        case custom
    }

    public enum Duration: Equatable {
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
            switch self {
            case .finite:
                return true
            case .indefinite:
                return false
            }
        }
    }

    public var context: Context
    public var settings: TemporaryScheduleOverrideSettings
    public var startDate: Date
    public var duration: Duration

    public var activeInterval: DateInterval {
        return DateInterval(start: startDate, duration: duration.timeInterval)
    }

    public func hasFinished(relativeTo date: Date = Date()) -> Bool {
        return date > activeInterval.end
    }

    public init(context: Context, settings: TemporaryScheduleOverrideSettings, startDate: Date, duration: Duration) {
        self.context = context
        self.settings = settings
        self.startDate = startDate
        self.duration = duration
    }

    public func isActive(at date: Date = Date()) -> Bool {
        return activeInterval.contains(date)
    }
}

extension GlucoseRangeSchedule {
    public func applyingOverride(
        _ override: TemporaryScheduleOverride,
        relativeTo date: Date = Date(),
        calendar: Calendar = .current
    ) -> GlucoseRangeSchedule {
        let rangeSchedule = self.rangeSchedule.applyingGlucoseRangeOverride(from: override, relativeTo: date, calendar: calendar)
        return GlucoseRangeSchedule(rangeSchedule: rangeSchedule)
    }
}

extension DailyQuantitySchedule where T == DoubleRange {
    fileprivate func applyingGlucoseRangeOverride(
        from override: TemporaryScheduleOverride,
        relativeTo date: Date,
        calendar: Calendar
    ) -> DailyQuantitySchedule {
        return DailyQuantitySchedule(
            unit: unit,
            valueSchedule: valueSchedule.applyingOverride(
                during: override.activeInterval,
                relativeTo: date,
                calendar: calendar,
                updatingOverridenValuesWith: { _ in override.settings.targetRange }
            )
        )
    }
}

extension /* BasalRateSchedule */ DailyValueSchedule where T == Double {
    public func applyingBasalRateMultiplier(
        from override: TemporaryScheduleOverride,
        relativeTo date: Date = Date(),
        calendar: Calendar = .current
    ) -> BasalRateSchedule {
        return applyingOverride(override, relativeTo: date, calendar: calendar, multiplier: \.basalRateMultiplier)
    }
}

extension /* InsulinSensitivitySchedule */ DailyQuantitySchedule where T == Double {
    public func applyingSensitivityMultiplier(
        from override: TemporaryScheduleOverride,
        relativeTo date: Date = Date(),
        calendar: Calendar = .current
    ) -> InsulinSensitivitySchedule {
        return DailyQuantitySchedule(
            unit: unit,
            valueSchedule: valueSchedule.applyingOverride(
                override,
                relativeTo: date,
                calendar: calendar,
                multiplier: \.insulinSensitivityMultiplier
            )
        )
    }
}

extension /* CarbRatioSchedule */ DailyQuantitySchedule where T == Double {
    public func applyingCarbRatioMultiplier(
        from override: TemporaryScheduleOverride,
        relativeTo date: Date = Date(),
        calendar: Calendar = .current
    ) -> CarbRatioSchedule {
        return DailyQuantitySchedule(
            unit: unit,
            valueSchedule: valueSchedule.applyingOverride(
                override,
                relativeTo: date,
                calendar: calendar,
                multiplier: \.carbRatioMultiplier
            )
        )
    }
}

extension DailyValueSchedule where T == Double {
    fileprivate func applyingOverride(
        _ override: TemporaryScheduleOverride,
        relativeTo date: Date,
        calendar: Calendar,
        multiplier multiplierKeyPath: KeyPath<TemporaryScheduleOverrideSettings, Double?>
    ) -> DailyValueSchedule {
        guard let multiplier = override.settings[keyPath: multiplierKeyPath] else { return self }
        return applyingOverride(
            during: override.activeInterval,
            relativeTo: date,
            calendar: calendar,
            updatingOverridenValuesWith: { $0 * multiplier }
        )
    }
}

extension DailyValueSchedule {
    fileprivate func applyingOverride(
        during activeInterval: DateInterval,
        relativeTo date: Date,
        calendar: Calendar,
        updatingOverridenValuesWith update: (T) -> T
    ) -> DailyValueSchedule {
        guard let activeInterval = clamping(activeInterval, to: date, calendar: calendar) else {
            // Active interval does not fall within this date; schedule is unchanged
            return self
        }

        let overrideStartOffset = scheduleOffset(for: activeInterval.start)
        let overrideEndOffset = scheduleOffset(for: activeInterval.end)

        guard overrideStartOffset != overrideEndOffset else {
            // Full schedule is overridden
            let overriddenSchedule = items.map { item in
                RepeatingScheduleValue(startTime: item.startTime, value: update(item.value))
            }
            return DailyValueSchedule(dailyItems: overriddenSchedule, timeZone: timeZone)!
        }

        let scheduleItemsIncludingOverride = scheduleItemsPaddedToClosedInterval
            .adjacentPairs()
            .flatMap { item, nextItem -> [RepeatingScheduleValue<T>] in
                let scheduleItemInterval = item.startTime..<nextItem.startTime

                switch (scheduleItemInterval.contains(overrideStartOffset), scheduleItemInterval.contains(overrideEndOffset)) {
                case (true, true):
                    // Override fully contained by this segment
                    let overrideStart = RepeatingScheduleValue(startTime: overrideStartOffset, value: update(item.value))
                    let overrideEnd = RepeatingScheduleValue(startTime: overrideEndOffset, value: item.value)
                    if item.startTime == overrideStartOffset {
                        // Ignore the existing schedule item
                        return [overrideStart, overrideEnd]
                    } else {
                        // Include the start of the existing item up until the override start
                        return [item, overrideStart, overrideEnd]
                    }
                case (true, false):
                    // Override begins within this segment
                    let overrideStart = RepeatingScheduleValue(startTime: overrideStartOffset, value: update(item.value))
                    if item.startTime == overrideStartOffset {
                        // Ignore the existing schedule item
                        return [overrideStart]
                    } else {
                        // Include the start of the existing item up until the override start
                        return [item, overrideStart]
                    }
                case (false, true):
                    // Override ends within this segment
                    if item.startTime == overrideEndOffset {
                        // Override ends here naturally
                        return [item]
                    } else {
                        // Include partially overriden item up until end
                        let partiallyOverridenItem = RepeatingScheduleValue(startTime: item.startTime, value: update(item.value))
                        let overrideEnd = RepeatingScheduleValue(startTime: overrideEndOffset, value: item.value)
                        return [partiallyOverridenItem, overrideEnd]
                    }
                case (false, false):
                    // Segment is either disjoint with the override -> should remain unaffected
                    // or fully encapsulated by the override -> should be updated
                    if item.startTime < overrideStartOffset || item.startTime > overrideEndOffset {
                        // The item is unaffected
                        return [item]
                    } else {
                        // The item is fully overriden
                        let overridenItem = RepeatingScheduleValue(startTime: item.startTime, value: update(item.value))
                        return [overridenItem]
                    }
                }
            }

        return DailyValueSchedule(
            dailyItems: scheduleItemsIncludingOverride,
            timeZone: timeZone
        )!
    }

    func clamping(_ interval: DateInterval, to date: Date, calendar: Calendar) -> DateInterval? {
        let (startHour, startMinute) = referenceTimeInterval.hourAndMinuteComponents
        let (endHour, endMinute) = maxTimeInterval.hourAndMinuteComponents
        guard
            let startOfDateRelativeToSchedule = calendar.date(bySettingHour: startHour, minute: startMinute, second: 0, of: date),
            var endOfDateRelativeToSchedule = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: date)
        else {
            assertionFailure("Unable to compute dates relative to schedule using \(calendar)")
            return interval
        }

        if endOfDateRelativeToSchedule <= startOfDateRelativeToSchedule {
            endOfDateRelativeToSchedule += repeatInterval
        }

        let scheduleInterval = DateInterval(start: startOfDateRelativeToSchedule, end: endOfDateRelativeToSchedule)
        guard scheduleInterval.intersects(interval) else {
            // Interval falls on a different day
            return nil
        }

        let startDate = max(interval.start, startOfDateRelativeToSchedule)
        let endDate = min(interval.end, endOfDateRelativeToSchedule)
        return DateInterval(start: startDate, end: endDate)
    }

    /// Pads the schedule with an extra item to form a closed interval.
    private var scheduleItemsPaddedToClosedInterval: [RepeatingScheduleValue<T>] {
        guard let lastItem = items.last else {
            assertionFailure("Schedule should never be empty")
            return []
        }
        let lastItemStartingAtDayEnd = RepeatingScheduleValue(startTime: maxTimeInterval, value: lastItem.value)
        return items + [lastItemStartingAtDayEnd]
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
        self.init(context: context, settings: settings, startDate: startDate, duration: duration)
    }

    public var rawValue: RawValue {
        return [
            "context": context.rawValue,
            "settings": settings.rawValue,
            "startDate": startDate.timeIntervalSince1970,
            "duration": duration.rawValue
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

private extension GlucoseRangeSchedule {
    init(rangeSchedule: DailyQuantitySchedule<DoubleRange>) {
        self.rangeSchedule = rangeSchedule
    }
}

private extension DailyQuantitySchedule {
    init(unit: HKUnit, valueSchedule: DailyValueSchedule<T>) {
        self.unit = unit
        self.valueSchedule = valueSchedule
    }
}

private extension Collection {
    func adjacentPairs() -> Zip2Sequence<Self, SubSequence> {
        return zip(self, dropFirst())
    }
}

private extension TimeInterval {
    var hourAndMinuteComponents: (hour: Int, minute: Int) {
        let base = self.truncatingRemainder(dividingBy: .hours(24))
        let hour = Int(base.hours)
        let minute = Int((base - .hours(Double(hour))).minutes)
        return (hour, minute)
    }
}
