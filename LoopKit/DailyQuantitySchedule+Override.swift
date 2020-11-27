//
//  DailyQuantitySchedule+Override.swift
//  LoopKit
//
//  Created by Michael Pangburn on 3/26/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit


extension GlucoseRangeSchedule {
    public func applyingOverride(_ override: TemporaryScheduleOverride) -> GlucoseRangeSchedule {
        guard let targetRange = override.settings.targetRange else {
            return self
        }

        let doubleRange = targetRange.doubleRange(for: unit)
        let rangeOverride = GlucoseRangeSchedule.Override(value: doubleRange, start: override.startDate, end: override.scheduledEndDate)
        return GlucoseRangeSchedule(rangeSchedule: rangeSchedule, override: rangeOverride)
    }
}

extension /* BasalRateSchedule */ DailyValueSchedule where T == Double {
    func applyingBasalRateMultiplier(
        from override: TemporaryScheduleOverride,
        relativeTo date: Date = Date()
    ) -> BasalRateSchedule {
        return applyingOverride(override, relativeTo: date, multiplier: \.basalRateMultiplier)
    }
}

extension /* InsulinSensitivitySchedule */ DailyQuantitySchedule where T == Double {
    func applyingSensitivityMultiplier(
        from override: TemporaryScheduleOverride,
        relativeTo date: Date = Date()
    ) -> InsulinSensitivitySchedule {
        return DailyQuantitySchedule(
            unit: unit,
            valueSchedule: valueSchedule.applyingOverride(
                override,
                relativeTo: date,
                multiplier: \.insulinSensitivityMultiplier
            )
        )
    }
}

extension /* CarbRatioSchedule */ DailyQuantitySchedule where T == Double {
    func applyingCarbRatioMultiplier(
        from override: TemporaryScheduleOverride,
        relativeTo date: Date = Date()
    ) -> CarbRatioSchedule {
        return DailyQuantitySchedule(
            unit: unit,
            valueSchedule: valueSchedule.applyingOverride(
                override,
                relativeTo: date,
                multiplier: \.carbRatioMultiplier
            )
        )
    }
}

extension DailyValueSchedule where T == Double {
    fileprivate func applyingOverride(
        _ override: TemporaryScheduleOverride,
        relativeTo date: Date,
        multiplier multiplierKeyPath: KeyPath<TemporaryScheduleOverrideSettings, Double?>
    ) -> DailyValueSchedule {
        guard let multiplier = override.settings[keyPath: multiplierKeyPath] else {
            return self
        }
        return applyingOverride(
            during: override.activeInterval,
            relativeTo: date,
            updatingOverridenValuesWith: { $0 * multiplier }
        )
    }
}

extension DailyValueSchedule {
    fileprivate func applyingOverride(
        during activeInterval: DateInterval,
        relativeTo referenceDate: Date,
        updatingOverridenValuesWith update: (T) -> T
    ) -> DailyValueSchedule {
        guard let activeInterval = clampingToAffectedInterval(activeInterval, relativeTo: referenceDate) else {
            // Override has no effect relative to the reference date
            return self
        }

        let overrideStartOffset = scheduleOffset(for: activeInterval.start)
        let overrideEndOffset = scheduleOffset(for: activeInterval.end)
        guard overrideStartOffset != overrideEndOffset else {
            // Full schedule overridden
            return DailyValueSchedule(
                dailyItems: items.map { item in RepeatingScheduleValue(startTime: item.startTime, value: update(item.value)) },
                timeZone: timeZone
            )!
        }

        let overrideCrossesMidnight = overrideStartOffset > overrideEndOffset
        let scheduleItemsIncludingOverride = scheduleItemsPaddedToClosedInterval
            .adjacentPairs()
            .flatMap { item, nextItem -> [RepeatingScheduleValue<T>] in
                let overriddenItemValue = update(item.value)
                let overriddenItem = RepeatingScheduleValue(startTime: item.startTime, value: overriddenItemValue)
                let overrideStart = RepeatingScheduleValue(startTime: overrideStartOffset, value: overriddenItemValue)
                let overrideEnd = RepeatingScheduleValue(startTime: overrideEndOffset, value: item.value)

                let scheduleItemInterval = item.startTime..<nextItem.startTime
                let overrideStartsInThisSegment = scheduleItemInterval.contains(overrideStartOffset)
                let overrideEndsInThisSegment = scheduleItemInterval.contains(overrideEndOffset)

                switch (overrideStartsInThisSegment, overrideEndsInThisSegment) {
                case (true, true):
                    if overrideCrossesMidnight {
                        return item.startTime == overrideEndOffset
                            ? [overrideEnd, overrideStart]
                            : [overriddenItem, overrideEnd, overrideStart]
                    } else {
                        return item.startTime == overrideStartOffset
                            ? [overrideStart, overrideEnd]
                            : [item, overrideStart, overrideEnd]
                    }
                case (true, false):
                    return item.startTime == overrideStartOffset
                        ? [overrideStart]
                        : [item, overrideStart]
                case (false, true):
                    return item.startTime == overrideEndOffset
                        ? [overrideEnd]
                        : [overriddenItem, overrideEnd]
                case (false, false):
                    let segmentIsDisjointWithOverride = overrideCrossesMidnight
                        ? overrideEndOffset...overrideStartOffset ~= item.startTime
                        : !(overrideStartOffset...overrideEndOffset ~= item.startTime)
                    return segmentIsDisjointWithOverride
                        ? [item]
                        : [overriddenItem]
                }
        }

        return DailyValueSchedule(
            dailyItems: scheduleItemsIncludingOverride,
            timeZone: timeZone
        )!
    }

    /// Clamps the override date interval to the relevant period of effect given a reference date.
    /// Returns `nil` if an override during the given interval has no effect relative to the reference date.
    private func clampingToAffectedInterval(_ interval: DateInterval, relativeTo referenceDate: Date) -> DateInterval? {
        let relevantPeriodStart = referenceDate.addingTimeInterval(-repeatInterval)
        let relevantPeriodEnd = referenceDate.addingTimeInterval(repeatInterval)

        guard
            interval.end > relevantPeriodStart,
            interval.start < relevantPeriodEnd
        else {
            return nil
        }

        let startDate = max(interval.start, relevantPeriodStart)
        let endDate = min(interval.end, relevantPeriodEnd)
        let affectedInterval = DateInterval(start: startDate, end: endDate)
        return affectedInterval
    }

    /// Pads the schedule with an extra item to form a closed interval.
    private var scheduleItemsPaddedToClosedInterval: [RepeatingScheduleValue<T>] {
        guard let lastItem = items.last else {
            assertionFailure("Schedule can never be empty")
            return []
        }
        let lastItemStartingAtDayEnd = RepeatingScheduleValue(startTime: maxTimeInterval, value: lastItem.value)
        return items + [lastItemStartingAtDayEnd]
    }
}

