//
//  GlucoseRangeSchedule+SafeBounds.swift
//  LoopKit
//
//  Created by Noah Brauner on 12/5/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

extension GlucoseRangeSchedule {
    public func safeSchedule(with suspendThreshold: Double?, unit: HKUnit) -> GlucoseRangeSchedule? {
        var min: Double!
        min = [
            suspendThreshold,
            Guardrail.correctionRange.absoluteBounds.lowerBound.doubleValue(for: unit)
        ]
            .compactMap({ $0 })
            .max()
        let filteredItems = rangeSchedule.valueSchedule.items.map { scheduleValue in
            let newScheduleValue = DoubleRange(minValue: max(min, scheduleValue.value.minValue), maxValue: max(min, scheduleValue.value.maxValue))
            return RepeatingScheduleValue(startTime: scheduleValue.startTime, value: newScheduleValue)
        }
        guard let filteredRangeSchedule = DailyQuantitySchedule(unit: rangeSchedule.unit, dailyItems: filteredItems) else {
            return nil
        }
        return GlucoseRangeSchedule(rangeSchedule: filteredRangeSchedule, override: self.override)
    }
}
