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


struct CarbMath {
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

    private static func absorbedCarbs(_ carbs: Double, atTime time: TimeInterval, absorptionTime: TimeInterval) -> Double {
        return carbs * percentAbsorptionAtTime(time, absorptionTime: absorptionTime)
    }

    private static func unabsorbedCarbs(_ carbs: Double, atTime time: TimeInterval, absorptionTime: TimeInterval) -> Double {
        return carbs * (1 - percentAbsorptionAtTime(time, absorptionTime: absorptionTime))
    }

    private static func carbsOnBoardForCarbEntry(_ entry: CarbEntry, at date: Date, defaultAbsorptionTime: TimeInterval, delay: TimeInterval) -> Double {
        let time = date.timeIntervalSince(entry.startDate)
        let value: Double

        if time >= 0 {
            value = unabsorbedCarbs(entry.quantity.doubleValue(for: HKUnit.gram()), atTime: time - delay, absorptionTime: entry.absorptionTime ?? defaultAbsorptionTime)
        } else {
            value = 0
        }

        return value
    }

    // mg/dL / g * g
    private static func glucoseEffectForCarbEntry(
        _ entry: CarbEntry,
        atDate date: Date,
        carbRatio: HKQuantity,
        insulinSensitivity: HKQuantity,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval
    ) -> Double {
        let time = date.timeIntervalSince(entry.startDate)
        let value: Double
        let unit = HKUnit.gram()

        if time >= 0 {
            value = insulinSensitivity.doubleValue(for: HKUnit.milligramsPerDeciliterUnit()) / carbRatio.doubleValue(for: unit) * absorbedCarbs(entry.quantity.doubleValue(for: unit), atTime: time - delay, absorptionTime: entry.absorptionTime ?? defaultAbsorptionTime)
        } else {
            value = 0
        }

        return value
    }

    private static func simulationDateRangeForCarbEntries<T: Collection>(
        _ entries: T,
        fromDate: Date?,
        toDate: Date?,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval,
        delta: TimeInterval
    ) -> (Date, Date)? where T.Iterator.Element: CarbEntry {
        var maxAbsorptionTime = defaultAbsorptionTime

        for entry in entries {
            if let absorptionTime = entry.absorptionTime, absorptionTime > maxAbsorptionTime {
                maxAbsorptionTime = absorptionTime
            }
        }

        return LoopMath.simulationDateRangeForSamples(entries, fromDate: fromDate, toDate: toDate, duration: maxAbsorptionTime, delay: delay, delta: delta)
    }

    static func carbsOnBoardForCarbEntries<T: Collection>(
        _ entries: T,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [CarbValue] where T.Iterator.Element: CarbEntry {
        guard let (startDate, endDate) = simulationDateRangeForCarbEntries(entries, fromDate: fromDate, toDate: toDate, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, delta: delta) else {
            return []
        }

        var date = startDate
        var values = [CarbValue]()

        repeat {
            let value = entries.reduce(0.0) { (value, entry) -> Double in
                return value + carbsOnBoardForCarbEntry(entry, at: date, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay)
            }

            values.append(CarbValue(startDate: date, quantity: HKQuantity(unit: HKUnit.gram(), doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= endDate

        return values
    }

    static func glucoseEffectsForCarbEntries<T: Collection>(
        _ entries: T,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        carbRatios: CarbRatioSchedule,
        insulinSensitivities: InsulinSensitivitySchedule,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [GlucoseEffect] where T.Iterator.Element: CarbEntry {
        guard let (startDate, endDate) = simulationDateRangeForCarbEntries(entries, fromDate: fromDate, toDate: toDate, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, delta: delta) else {
            return []
        }

        var date = startDate
        var values = [GlucoseEffect]()
        let unit = HKUnit.milligramsPerDeciliterUnit()

        repeat {
            let value = entries.reduce(0.0) { (value, entry) -> Double in
                return value + glucoseEffectForCarbEntry(entry, atDate: date, carbRatio: carbRatios.quantity(at: entry.startDate), insulinSensitivity: insulinSensitivities.quantity(at: entry.startDate), defaultAbsorptionTime: defaultAbsorptionTime, delay: delay)
            }

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: unit, doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= endDate

        return values
    }

    static func totalCarbsForCarbEntries<T: Collection>(_ entries: T) -> CarbValue? where T.Iterator.Element: CarbEntry {
        guard entries.count > 0 else {
            return nil
        }

        let unit = HKUnit.gram()
        var startDate = Date.distantFuture
        var totalGrams: Double = 0

        for entry in entries {
            totalGrams += entry.quantity.doubleValue(for: unit)

            if entry.startDate < startDate {
                startDate = entry.startDate
            }
        }

        return CarbValue(startDate: startDate, quantity: HKQuantity(unit: unit, doubleValue: totalGrams))
    }
}
