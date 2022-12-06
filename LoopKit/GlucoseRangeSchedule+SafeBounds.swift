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
    public func safeSchedule(with suspendThreshold: GlucoseThreshold?) -> GlucoseRangeSchedule? {
        var glucoseScheduleMinimunValue: Double!
        if let threshold = suspendThreshold {
            glucoseScheduleMinimunValue = Guardrail.minCorrectionRangeValue(suspendThreshold: threshold).doubleValue(for: threshold.unit)
        }
        else {
            glucoseScheduleMinimunValue = Guardrail.correctionRange.absoluteBounds.lowerBound.doubleValue(for: .milligramsPerDeciliter)
        }
        return rangeScheduleWithMin(min: glucoseScheduleMinimunValue)
    }

    private func rangeScheduleWithMin(min: Double) -> GlucoseRangeSchedule? {
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
