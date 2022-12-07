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
        let minGlucoseValue = [
            suspendThreshold,
            Guardrail.correctionRange.absoluteBounds.lowerBound.doubleValue(for: unit)
        ]
            .compactMap({ $0 })
            .max()!
        let maxGlucoseValue = Guardrail.correctionRange.absoluteBounds.upperBound.doubleValue(for: unit)
        
        func safeGlucoseValue(_ initialValue: Double) -> Double {
            return max(minGlucoseValue, min(maxGlucoseValue, initialValue))
        }
        
        let filteredItems = rangeSchedule.valueSchedule.items.map { scheduleValue in
            let newScheduleValue = DoubleRange(minValue: safeGlucoseValue(scheduleValue.value.minValue), maxValue: safeGlucoseValue(scheduleValue.value.maxValue))
            return RepeatingScheduleValue(startTime: scheduleValue.startTime, value: newScheduleValue)
        }
        guard let filteredRangeSchedule = DailyQuantitySchedule(unit: rangeSchedule.unit, dailyItems: filteredItems) else {
            return nil
        }
        return GlucoseRangeSchedule(rangeSchedule: filteredRangeSchedule, override: self.override)
    }
}
