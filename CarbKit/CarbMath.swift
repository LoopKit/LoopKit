//
//  CarbMath.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/16/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit


public struct CarbValue: SampleValue {
    public let startDate: Date
    public let quantity: HKQuantity
}


enum CarbMath {
    /**
     Returns the percentage of total carbohydrates absorbed as blood glucose at a specified interval after eating.

     This is the integral approximation of the Scheiner GI curve found in Think Like a Pancreas, Fig 7-8, which first appeared in [GlucoDyn](https://github.com/kenstack/GlucoDyn)

     - parameter time:           The interval after the carbs were eaten
     - parameter absorptionTime: The total time of carb absorption

     - returns: The percentage of the total carbohydrates that have been absorbed as blood glucose
     */
    private static func percentAbsorptionAtTime(_ time: TimeInterval, absorptionTime: TimeInterval) -> Double {
        switch time {
        case let t where t < 0:
            return 0
        case let t where t <= absorptionTime / 2:
            return 2 / pow(absorptionTime, 2) * pow(t, 2)
        case let t where t < absorptionTime:
            return -1 + 4 / absorptionTime * (t - pow(t, 2) / (2 * absorptionTime))
        default:
            return 1
        }
    }

    fileprivate static func absorbedCarbs(_ carbs: Double, atTime time: TimeInterval, absorptionTime: TimeInterval) -> Double {
        return carbs * percentAbsorptionAtTime(time, absorptionTime: absorptionTime)
    }

    fileprivate static func unabsorbedCarbs(_ carbs: Double, atTime time: TimeInterval, absorptionTime: TimeInterval) -> Double {
        return carbs * (1 - percentAbsorptionAtTime(time, absorptionTime: absorptionTime))
    }
}


extension CarbEntry {
    fileprivate func carbsOnBoard(at date: Date, defaultAbsorptionTime: TimeInterval, delay: TimeInterval) -> Double {
        let time = date.timeIntervalSince(startDate)
        let value: Double

        if time >= 0 {
            value = CarbMath.unabsorbedCarbs(quantity.doubleValue(for: HKUnit.gram()), atTime: time - delay, absorptionTime: absorptionTime ?? defaultAbsorptionTime)
        } else {
            value = 0
        }

        return value
    }

    // mg/dL / g * g
    fileprivate func glucoseEffect(
        at date: Date,
        carbRatio: HKQuantity,
        insulinSensitivity: HKQuantity,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval
    ) -> Double {
        let time = date.timeIntervalSince(startDate)
        let value: Double
        let unit = HKUnit.gram()

        if time >= 0 {
            value = insulinSensitivity.doubleValue(for: HKUnit.milligramsPerDeciliter()) / carbRatio.doubleValue(for: unit) * CarbMath.absorbedCarbs(quantity.doubleValue(for: unit), atTime: time - delay, absorptionTime: absorptionTime ?? defaultAbsorptionTime)
        } else {
            value = 0
        }

        return value
    }
}

extension Collection where Iterator.Element: CarbEntry {
    private func simulationDateRange(
        from start: Date? = nil,
        to end: Date? = nil,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval,
        delta: TimeInterval
    ) -> (start: Date, end: Date)? {
        var maxAbsorptionTime = defaultAbsorptionTime

        for entry in self {
            if let absorptionTime = entry.absorptionTime, absorptionTime > maxAbsorptionTime {
                maxAbsorptionTime = absorptionTime
            }
        }

        return LoopMath.simulationDateRangeForSamples(self, from: start, to: end, duration: maxAbsorptionTime, delay: delay, delta: delta)
    }

    /// Creates groups of entries that have overlapping absorption date intervals
    ///
    /// - Parameters:
    ///   - defaultAbsorptionTime: The default absorption time value, if not set on the entry
    /// - Returns: An array of arrays representing groups of entries, in chronological order by entry startDate
    func groupedByOverlappingAbsorptionTimes(
        defaultAbsorptionTime: TimeInterval
    ) -> [[Iterator.Element]] {
        var batches: [[Iterator.Element]] = []

        for entry in sorted(by: { $0.startDate < $1.startDate }) {
            if let lastEntry = batches.last?.last,
                lastEntry.startDate.addingTimeInterval(lastEntry.absorptionTime ?? defaultAbsorptionTime) > entry.startDate
            {
                batches[batches.count - 1].append(entry)
            } else {
                batches.append([entry])
            }
        }

        return batches
    }

    func carbsOnBoard(
        from start: Date? = nil,
        to end: Date? = nil,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [CarbValue] {
        guard let (startDate, endDate) = simulationDateRange(from: start, to: end, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, delta: delta) else {
            return []
        }

        var date = startDate
        var values = [CarbValue]()

        repeat {
            let value = reduce(0.0) { (value, entry) -> Double in
                return value + entry.carbsOnBoard(at: date, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay)
            }

            values.append(CarbValue(startDate: date, quantity: HKQuantity(unit: HKUnit.gram(), doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= endDate

        return values
    }

    func glucoseEffects(
        from start: Date? = nil,
        to end: Date? = nil,
        carbRatios: CarbRatioSchedule,
        insulinSensitivities: InsulinSensitivitySchedule,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [GlucoseEffect] {
        guard let (startDate, endDate) = simulationDateRange(from: start, to: end, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, delta: delta) else {
            return []
        }

        var date = startDate
        var values = [GlucoseEffect]()
        let unit = HKUnit.milligramsPerDeciliter()

        repeat {
            let value = reduce(0.0) { (value, entry) -> Double in
                return value + entry.glucoseEffect(at: date, carbRatio: carbRatios.quantity(at: entry.startDate), insulinSensitivity: insulinSensitivities.quantity(at: entry.startDate), defaultAbsorptionTime: defaultAbsorptionTime, delay: delay)
            }

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: unit, doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= endDate

        return values
    }

    var totalCarbs: CarbValue? {
        guard count > 0 else {
            return nil
        }

        let unit = HKUnit.gram()
        var startDate = Date.distantFuture
        var totalGrams: Double = 0

        for entry in self {
            totalGrams += entry.quantity.doubleValue(for: unit)

            if entry.startDate < startDate {
                startDate = entry.startDate
            }
        }

        return CarbValue(startDate: startDate, quantity: HKQuantity(unit: unit, doubleValue: totalGrams))
    }
}
