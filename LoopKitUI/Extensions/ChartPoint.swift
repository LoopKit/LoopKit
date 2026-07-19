//
//  ChartPoint.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit
import LoopAlgorithm

/// A shaded horizontal band on the glucose chart representing a correction range interval.
public struct TargetChartBar: Equatable {
    public let startDate: Date
    public let endDate: Date
    public let minValue: Double
    public let maxValue: Double
    public let isOverride: Bool
}

extension TargetChartBar {
    static func barsForGlucoseRangeSchedule(_ glucoseRangeSchedule: GlucoseRangeSchedule, unit: LoopUnit, chartStartDate: Date, chartEndDate: Date, considering potentialOverride: TemporaryScheduleOverride? = nil) -> [TargetChartBar] {
        let targetRanges = glucoseRangeSchedule.quantityBetween(
            start: chartStartDate,
            end: chartEndDate
        )

        var result = [TargetChartBar?]()

        for (index, range) in targetRanges.enumerated() {
            var startDate = range.startDate
            var endDate: Date

            if index == targetRanges.startIndex {
                startDate = chartStartDate
            }

            if index == targetRanges.endIndex - 1 {
                endDate = chartEndDate
            } else {
                endDate = targetRanges[index + 1].startDate
            }

            if let override = potentialOverride,
               startDate < endDate,
               (override.startDate...override.scheduledEndDate).overlaps(startDate...endDate)
            {
                result.append(createBar(value: range.value, unit: unit, startDate: startDate, endDate: override.startDate, isOverride: false))
                let targetDuringOverride = override.settings.targetRange ?? range.value
                result.append(createBar(
                    value: targetDuringOverride,
                    unit: unit,
                    startDate: max(override.startDate, startDate),
                    endDate: min(override.scheduledEndDate, endDate),
                    isOverride: true))
                result.append(createBar(value: range.value, unit: unit, startDate: override.scheduledEndDate, endDate: endDate, isOverride: false))
            } else {
                result.append(createBar(value: range.value, unit: unit, startDate: startDate, endDate: endDate, isOverride: false))
            }
        }

        return result.compactMap { $0 }
    }

    static fileprivate func createBar(value: ClosedRange<LoopQuantity>, unit: LoopUnit, startDate: Date, endDate: Date, isOverride: Bool) -> TargetChartBar? {
        guard startDate < endDate else { return nil }

        let value = value.doubleRangeWithMinimumIncrement(in: unit)

        return TargetChartBar(
            startDate: startDate,
            endDate: endDate,
            minValue: value.minValue,
            maxValue: value.maxValue,
            isOverride: isOverride)
    }

    static func barForGlucoseRangeScheduleOverride(_ override: TemporaryScheduleOverride, unit: LoopUnit, chartEndDate: Date, extendEndDateToChart: Bool = false) -> TargetChartBar? {
        guard let targetRange = override.settings.targetRange else {
            return nil
        }

        let range = targetRange.doubleRangeWithMinimumIncrement(in: unit)
        let activeInterval = override.activeInterval
        let displayEndDate = min(chartEndDate, extendEndDateToChart ? .distantFuture : activeInterval.end)

        guard activeInterval.start < displayEndDate else {
            return nil
        }

        return TargetChartBar(
            startDate: activeInterval.start,
            endDate: displayEndDate,
            minValue: range.minValue,
            maxValue: range.maxValue,
            isOverride: true)
    }
}


private extension ClosedRange where Bound == LoopQuantity {
    func doubleRangeWithMinimumIncrement(in unit: LoopUnit) -> DoubleRange {
        let increment = unit.chartableIncrement

        var minValue = self.lowerBound.doubleValue(for: unit)
        var maxValue = self.upperBound.doubleValue(for: unit)

        if (maxValue - minValue) < .ulpOfOne {
            minValue -= increment
            maxValue += increment
        }

        return DoubleRange(minValue: minValue, maxValue: maxValue)
    }
}
