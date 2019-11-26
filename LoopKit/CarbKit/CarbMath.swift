//
//  CarbMath.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/16/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


struct CarbModelSettings {
    var absorptionModel: CarbAbsorptionComputable
    var initialAbsorptionTimeOverrun: Double
    var adaptiveAbsorptionRateEnabled: Bool
    var adaptiveRateStandbyIntervalFraction: Double
    
    init(absorptionModel: CarbAbsorptionComputable, initialAbsorptionTimeOverrun: Double, adaptiveAbsorptionRateEnabled: Bool, adaptiveRateStandbyIntervalFraction: Double = 0.2) {
        self.absorptionModel = absorptionModel
        self.initialAbsorptionTimeOverrun = initialAbsorptionTimeOverrun
        self.adaptiveAbsorptionRateEnabled = adaptiveAbsorptionRateEnabled
        self.adaptiveRateStandbyIntervalFraction = adaptiveRateStandbyIntervalFraction
    }
}

protocol CarbAbsorptionComputable {
    /// Returns the percentage of total carbohydrates absorbed as blood glucose at a specified interval after eating.
    ///
    /// - Parameters:
    ///   - percentTime: The percentage of the total absorption time
    /// - Returns: The percentage of the total carbohydrates that have been absorbed as blood glucose
    func percentAbsorptionAtPercentTime(_ percentTime: Double) -> Double
    
    /// Returns the percent of total absorption time for a percentage of total carbohydrates absorbed
    ///
    /// The is the inverse of perecentAbsorptionAtPercentTime( :percentTime: )
    ///
    /// - Parameters:
    ///   - percentAbsorption: The percentage of the total carbohydrates that have been absorbed as blood glucose
    /// - Returns: The percentage of the absorption time needed to absorb the percentage of the total carbohydrates
    func percentTimeAtPercentAbsorption(_ percentAbsorption: Double) -> Double

    /// Returns the total absorption time for a percentage of total carbohydrates absorbed as blood glucose at a specified interval after eating.
    ///
    /// - Parameters:
    ///   - percentAbsorption: The percentage of the total carbohydrates that have been absorbed as blood glucose
    ///   - time: The interval after the carbohydrates were eaten
    /// - Returns: The total time of carbohydrates absorption
    func absorptionTime(forPercentAbsorption percentAbsorption: Double, atTime time: TimeInterval) -> TimeInterval

    /// Returns the number of total carbohydrates absorbed as blood glucose at a specified interval after eating
    ///
    /// - Parameters:
    ///   - total: The total number of carbohydrates eaten
    ///   - time: The interval after carbohydrates were eaten
    ///   - absorptionTime: The total time of carbohydrates absorption
    /// - Returns: The number of total carbohydrates that have been absorbed as blood glucose
    func absorbedCarbs(of total: Double, atTime time: TimeInterval, absorptionTime: TimeInterval) -> Double

    /// Returns the number of total carbohydrates not yet absorbed as blood glucose at a specified interval after eating
    ///
    /// - Parameters:
    ///   - total: The total number of carbs eaten
    ///   - time: The interval after carbohydrates were eaten
    ///   - absorptionTime: The total time of carb absorption
    /// - Returns: The number of total carbohydrates that have not yet been absorbed as blood glucose
    func unabsorbedCarbs(of total: Double, atTime time: TimeInterval, absorptionTime: TimeInterval) -> Double
    
    /// Returns the normalized rate of carbohydrates absorption at a specified percentage of the absorption time
    ///
    /// - Parameters:
    ///   - percentTime: The percentage of absorption time elapsed since the carbohydrates were eaten
    /// - Returns: The percentage absorption rate at the percentage of absorption time
    func percentRateAtPercentTime(forPercentTime percentTime: Double) -> Double
}


extension CarbAbsorptionComputable {
    func absorbedCarbs(of total: Double, atTime time: TimeInterval, absorptionTime: TimeInterval) -> Double {
        let percentTime = time / absorptionTime
        return total * percentAbsorptionAtPercentTime(percentTime)
    }

    func unabsorbedCarbs(of total: Double, atTime time: TimeInterval, absorptionTime: TimeInterval) -> Double {
        let percentTime = time / absorptionTime
        return total * (1.0 - percentAbsorptionAtPercentTime(percentTime))
    }
    
    func absorptionTime(forPercentAbsorption percentAbsorption: Double, atTime time: TimeInterval) -> TimeInterval {
        let percentTime = max(percentTimeAtPercentAbsorption(percentAbsorption), .ulpOfOne)
        return time / percentTime
    }
    
    func timeToAbsorb(forPercentAbsorbed percentAbsorption: Double, absorptionTime: TimeInterval) -> TimeInterval {
        let percentTime = percentTimeAtPercentAbsorption(percentAbsorption)
        return percentTime * absorptionTime
    }
    
}


// MARK: - Parabolic absorption as described by Scheiner
// This is the integral approximation of the Scheiner GI curve found in Think Like a Pancreas, Fig 7-8, which first appeared in [GlucoDyn](https://github.com/kenstack/GlucoDyn)
struct ParabolicAbsorption: CarbAbsorptionComputable {
    func percentAbsorptionAtPercentTime(_ percentTime: Double) -> Double {
        switch percentTime {
        case let t where t < 0.0:
            return 0.0
        case let t where t <= 0.5:
            return 2.0 * pow(t, 2)
        case let t where t < 1.0:
            return -1.0 + 2.0 * t * (2.0 - t)
        default:
            return 1.0
        }
    }

    func percentTimeAtPercentAbsorption(_ percentAbsorption: Double) -> Double {
        switch percentAbsorption {
        case let a where a <= 0:
            return 0
        case let a where a <= 0.5:
            return sqrt(0.5 * a)
        case let a where a < 1.0:
            return 1.0 - sqrt(0.5 * (1.0 - a))
        default:
            return 1.0
        }
    }
    
    func percentRateAtPercentTime(forPercentTime percentTime: Double) -> Double {
        switch percentTime {
        case let t where t > 0 && t <= 0.5:
            return 4.0 * t
        case let t where t > 0.5 && t < 1.0:
            return 4.0 - 4.0 * t
        default:
            return 0.0
        }
    }
}


// MARK: - Linear absorption as a factor of reported duration
struct LinearAbsorption: CarbAbsorptionComputable {
    func percentAbsorptionAtPercentTime(_ percentTime: Double) -> Double {
        switch percentTime {
        case let t where t <= 0.0:
            return 0.0
        case let t where t < 1.0:
            return t
        default:
            return 1.0
        }
    }

    func percentTimeAtPercentAbsorption(_ percentAbsorption: Double) -> Double {
        switch percentAbsorption {
        case let a where a <= 0.0:
            return 0.0
        case let a where a < 1.0:
            return a
        default:
            return 1.0
        }
    }
    
    func percentRateAtPercentTime(forPercentTime percentTime: Double) -> Double {
        switch percentTime {
        case let t where t > 0.0 && t <= 1.0:
            return 1.0
        default:
            return 0.0
        }
    }
}

// MARK: - Piecewise linear absorption as a factor of reported duration
/// Nonlinear  carb absorption model where absorption rate increases linearly from zero to a maximum value at a fraction of absorption time equal to percentEndOfRise, then remains constant until a fraction of absorption time equal to percentStartOfFall, and then decreases linearly to zero at the end of absorption time
/// - Parameters:
///   - percentEndOfRise: the percentage of absorption time when absorption rate reaches maximum, must be strictly between 0 and 1
///   - percentStartOfFall: the percentage of absorption time when absorption rate starts to decay, must be stritctly between 0 and 1 and  greater than percentEndOfRise
struct PiecewiseLinearAbsorption: CarbAbsorptionComputable {
    
    let percentEndOfRise = 0.15
    let percentStartOfFall = 0.5
    var scale: Double {
        return(2.0 / (1.0 + percentStartOfFall - percentEndOfRise))
    }
    
    func percentAbsorptionAtPercentTime(_ percentTime: Double) -> Double {
        switch percentTime {
        case let t where t <= 0.0:
            return 0.0
        case let t where t < percentEndOfRise:
            return 0.5 * scale * pow(t, 2.0) / percentEndOfRise
        case let t where t >= percentEndOfRise && t < percentStartOfFall:
            return scale * (t - 0.5 * percentEndOfRise)
        case let t where t >= percentStartOfFall && t < 1.0:
            return scale * (percentStartOfFall - 0.5 * percentEndOfRise +
            (t - percentStartOfFall) * (1.0 - 0.5 * (t - percentStartOfFall) / (1.0 - percentStartOfFall)))
        default:
            return 1.0
        }
    }
    
    func percentTimeAtPercentAbsorption(_ percentAbsorption: Double) -> Double {
        switch percentAbsorption {
        case let a where a <= 0:
            return 0
        case let a where a > 0.0 && a < 0.5 * scale * percentEndOfRise:
            return sqrt(2.0 * percentEndOfRise * a / scale)
        case let a where a >= 0.5 * scale * percentEndOfRise && a < scale * (percentStartOfFall - 0.5 * percentEndOfRise):
            return 0.5 * percentEndOfRise + a / scale
        case let a where a >= scale * (percentStartOfFall - 0.5 * percentEndOfRise) && a < 1.0:
            return 1.0 - sqrt((1.0 - percentStartOfFall) *
                (1.0 + percentStartOfFall - percentEndOfRise) * (1.0 - a))
        default:
            return 1.0
        }
    }
    
    func percentRateAtPercentTime(forPercentTime percentTime: Double) -> Double {
        switch percentTime {
        case let t where t <= 0:
            return 0.0
        case let t where t > 0 && t < percentEndOfRise:
            return scale * t / percentEndOfRise
        case let t where t >= percentEndOfRise && t < percentStartOfFall:
            return scale
        case let t where t >= percentStartOfFall && t < 1.0:
            return scale * ((1.0 - t) / (1.0 - percentStartOfFall))
        case let t where t == 1.0:
            return 0.0
        default:
            return 0.0
        }
    }
}

extension CarbEntry {
    
    func carbsOnBoard(at date: Date, defaultAbsorptionTime: TimeInterval, delay: TimeInterval, absorptionModel: CarbAbsorptionComputable) -> Double {
        let time = date.timeIntervalSince(startDate)
        let value: Double

        if time >= 0 {
            value = absorptionModel.unabsorbedCarbs(of: quantity.doubleValue(for: HKUnit.gram()), atTime: time - delay, absorptionTime: absorptionTime ?? defaultAbsorptionTime)
        } else {
            value = 0
        }

        return value
    }

    // g
    func absorbedCarbs(
        at date: Date,
        absorptionTime: TimeInterval,
        delay: TimeInterval,
        absorptionModel: CarbAbsorptionComputable
    ) -> Double {
        let time = date.timeIntervalSince(startDate)

        return absorptionModel.absorbedCarbs(
            of: quantity.doubleValue(for: .gram()),
            atTime: time - delay,
            absorptionTime: absorptionTime
        )
    }

    // mg/dL / g * g
    fileprivate func glucoseEffect(
        at date: Date,
        carbRatio: HKQuantity,
        insulinSensitivity: HKQuantity,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval,
        absorptionModel: CarbAbsorptionComputable
    ) -> Double {
        return insulinSensitivity.doubleValue(for: HKUnit.milligramsPerDeciliter) / carbRatio.doubleValue(for: .gram()) * absorbedCarbs(at: date, absorptionTime: absorptionTime ?? defaultAbsorptionTime, delay: delay, absorptionModel: absorptionModel)
    }

    fileprivate func estimatedAbsorptionTime(forAbsorbedCarbs carbs: Double, at date: Date, absorptionModel: CarbAbsorptionComputable) -> TimeInterval {
        let time = date.timeIntervalSince(startDate)

        return max(time, absorptionModel.absorptionTime(forPercentAbsorption: carbs / quantity.doubleValue(for: .gram()), atTime: time))
    }
}

extension Collection where Element: CarbEntry {
    fileprivate func simulationDateRange(
        from start: Date? = nil,
        to end: Date? = nil,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval,
        delta: TimeInterval
    ) -> (start: Date, end: Date)? {
        guard count > 0 else {
            return nil
        }

        if let start = start, let end = end {
            return (start: start.dateFlooredToTimeInterval(delta), end: end.dateCeiledToTimeInterval(delta))
        } else {
            var minDate = first!.startDate
            var maxDate = minDate

            for sample in self {
                if sample.startDate < minDate {
                    minDate = sample.startDate
                }

                let endDate = sample.endDate.addingTimeInterval(sample.absorptionTime ?? defaultAbsorptionTime).addingTimeInterval(delay)
                if endDate > maxDate {
                    maxDate = endDate
                }
            }

            return (
                start: (start ?? minDate).dateFlooredToTimeInterval(delta),
                end: (end ?? maxDate).dateCeiledToTimeInterval(delta)
            )
        }
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
        absorptionModel: CarbAbsorptionComputable,
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
                return value + entry.carbsOnBoard(at: date, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, absorptionModel: absorptionModel)
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
        absorptionModel: CarbAbsorptionComputable,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [GlucoseEffect] {
        guard let (startDate, endDate) = simulationDateRange(from: start, to: end, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, delta: delta) else {
            return []
        }

        var date = startDate
        var values = [GlucoseEffect]()
        let unit = HKUnit.milligramsPerDeciliter

        repeat {
            let value = reduce(0.0) { (value, entry) -> Double in
                return value + entry.glucoseEffect(
                    at: date,
                    carbRatio: carbRatios.quantity(at: entry.startDate),
                    insulinSensitivity: insulinSensitivities.quantity(at: entry.startDate),
                    defaultAbsorptionTime: defaultAbsorptionTime,
                    delay: delay,
                    absorptionModel: absorptionModel
                )
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


// MARK: - Dyanamic absorption overrides
extension Collection {
    func dynamicCarbsOnBoard<T>(
        from start: Date? = nil,
        to end: Date? = nil,
        defaultAbsorptionTime: TimeInterval,
        absorptionModel: CarbAbsorptionComputable,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [CarbValue] where Element == CarbStatus<T> {
        guard let (startDate, endDate) = simulationDateRange(from: start, to: end, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, delta: delta) else {
            return []
        }

        var date = startDate
        var values = [CarbValue]()

        repeat {
            let value = reduce(0.0) { (value, entry) -> Double in
                return value + entry.dynamicCarbsOnBoard(
                    at: date,
                    defaultAbsorptionTime: defaultAbsorptionTime,
                    delay: delay,
                    delta: delta,
                    absorptionModel: absorptionModel
                )
            }

            values.append(CarbValue(startDate: date, quantity: HKQuantity(unit: HKUnit.gram(), doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= endDate
        
        return values
    }

    func dynamicGlucoseEffects<T>(
        from start: Date? = nil,
        to end: Date? = nil,
        carbRatios: CarbRatioSchedule,
        insulinSensitivities: InsulinSensitivitySchedule,
        defaultAbsorptionTime: TimeInterval,
        absorptionModel: CarbAbsorptionComputable,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [GlucoseEffect] where Element == CarbStatus<T> {
        guard let (startDate, endDate) = simulationDateRange(from: start, to: end, defaultAbsorptionTime: defaultAbsorptionTime, delay: delay, delta: delta) else {
            return []
        }

        var date = startDate
        var values = [GlucoseEffect]()
        let mgdL = HKUnit.milligramsPerDeciliter
        let gram = HKUnit.gram()

        repeat {
            let value = reduce(0.0) { (value, entry) -> Double in
                let csf = insulinSensitivities.quantity(at: entry.startDate).doubleValue(for: mgdL) / carbRatios.quantity(at: entry.startDate).doubleValue(for: gram)

                return value + csf * entry.dynamicAbsorbedCarbs(
                    at: date,
                    absorptionTime: entry.absorptionTime ?? defaultAbsorptionTime,
                    delay: delay,
                    delta: delta,
                    absorptionModel: absorptionModel
                )
            }

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: mgdL, doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= endDate
        
        return values
    }

    /// The quantity of carbs expected to still absorb at the last date of absorption
    public func getClampedCarbsOnBoard<T>() -> CarbValue? where Element == CarbStatus<T> {
        guard let firstAbsorption = first?.absorption else {
            return nil
        }

        let gram = HKUnit.gram()
        var maxObservedEndDate = firstAbsorption.observedDate.end
        var remainingTotalGrams: Double = 0

        for entry in self {
            guard let absorption = entry.absorption else {
                continue
            }

            maxObservedEndDate = Swift.max(maxObservedEndDate, absorption.observedDate.end)
            remainingTotalGrams += absorption.remaining.doubleValue(for: gram)
        }

        return CarbValue(startDate: maxObservedEndDate, quantity: HKQuantity(unit: gram, doubleValue: remainingTotalGrams))
    }
}


/// Aggregates and computes data about the absorption of a CarbEntry to create a CarbStatus value.
///
/// There are three key components managed by this builder:
///   - The entry data as reported by the user
///   - The observed data as calculated from glucose changes relative to insulin curves
///   - The minimum/maximum amounts of absorption used to clamp our observation data within reasonable bounds
fileprivate class CarbStatusBuilder<T: CarbEntry> {

    // MARK: Model settings
    
    private var absorptionModel: CarbAbsorptionComputable
    
    private var adaptiveAbsorptionRateEnabled: Bool
   
    private var adaptiveRateStandbyIntervalFraction: Double
    
    private var adaptiveRateStandbyInterval: TimeInterval {
        return initialAbsorptionTime * adaptiveRateStandbyIntervalFraction
    }
    
    // MARK: User-entered data

    /// The carb entry input
    let entry: T

    /// The unit used for carb values
    let carbUnit: HKUnit

    /// The total grams entered for this entry
    let entryGrams: Double

    /// The total glucose effect expected for this entry, in glucose units
    let entryEffect: Double

    /// The carbohydrate-sensitivity factor for this entry, in glucose units per gram
    let carbohydrateSensitivityFactor: Double

    /// The absorption time for this entry before any absorption is observed
    let initialAbsorptionTime: TimeInterval

    // MARK: Minimum/maximum bounding factors

    /// The maximum absorption time allowed for this entry, determining the minimum absorption rate
    let maxAbsorptionTime: TimeInterval

    /// An amount of time to wait after the entry date before minimum absorption is assumed to begin
    let delay: TimeInterval

    /// The maximum end date allowed for this entry's absorption
    let maxEndDate: Date

    /// The last date we have effects observed, or "now" in real-time analysis.
    private let lastEffectDate: Date

    /// The minimum-required carb absorption rate for this entry, in g/s
    var minAbsorptionRate: Double {
        return entryGrams / maxAbsorptionTime
    }

    /// The minimum amount of carbs we assume must have absorbed at the last observation date
    private var minPredictedGrams: Double {
        // We incorporate a delay when calculating minimum absorption values
        let time = lastEffectDate.timeIntervalSince(entry.startDate) - delay
        return absorptionModel.absorbedCarbs(of: entryGrams, atTime: time, absorptionTime: maxAbsorptionTime)
    }

    // MARK: Incremental observation

    /// The date at which we observe all the carbs were absorbed. or nil if carb absorption has not finished
    private var observedCompletionDate: Date?

    /// The total observed effect for each entry, in glucose units
    private(set) var observedEffect: Double = 0

    /// The timeline of absorption amounts credited to this carb entry, in grams, for computation of historical COB and effect history
    private(set) var observedTimeline: [CarbValue] = []

    /// The amount of carbs we've observed absorbing
    private var observedGrams: Double {
        return observedEffect / carbohydrateSensitivityFactor
    }

    /// The amount of effect remaining until 100% of entry absorption is observed
    var remainingEffect: Double {
        return max(entryEffect - observedEffect, 0)
    }

    /// The dates over which we observed absorption, from start until 100% or last observed effect.
    private var observedAbsorptionDates: DateInterval {
        return DateInterval(start: entry.startDate, end: observedCompletionDate ?? lastEffectDate)
    }


    // MARK: Clamped results

    /// The number of carbs absorbed, suitable for use in calculations.
    /// This is bounded by minimumPredictedGrams and the entry total.
    private var clampedGrams: Double {
        let minPredictedGrams = self.minPredictedGrams

        return min(entryGrams, max(minPredictedGrams, observedGrams))
    }
    
    private var percentAbsorbed: Double {
        return clampedGrams / entryGrams
    }
    
    /// The amount of time needed to absorb observed grams
    private var timeToAbsorbObservedCarbs: TimeInterval {
        let time = lastEffectDate.timeIntervalSince(entry.startDate) - delay
        guard time > 0 else {
            return 0.0
        }
        var timeToAbsorb: TimeInterval
        if adaptiveAbsorptionRateEnabled && time > adaptiveRateStandbyInterval {
            // If adaptive absorption rate is enabled, and if the time since start of absorption is greater than the standby interval, the time to absorb observed carbs equals the obervation time
            timeToAbsorb = time
        } else {
            // If adaptive absorption rate is disabled, or if the time since start of absorption is less than the standby interval, the time to absorb observed carbs is calculated based on the absorption model
            timeToAbsorb = absorptionModel.timeToAbsorb(forPercentAbsorbed: percentAbsorbed, absorptionTime: initialAbsorptionTime)
        }
        return min(timeToAbsorb, maxAbsorptionTime)
    }
    
    /// The amount of time needed for the remaining entry grams to absorb
    private var estimatedTimeRemaining: TimeInterval {
        let time = lastEffectDate.timeIntervalSince(entry.startDate) - delay
        guard time > 0 else {
            return initialAbsorptionTime
        }
        let notToExceedTimeRemaining = max(maxAbsorptionTime - time, 0.0)
        guard notToExceedTimeRemaining > 0 else {
            return 0.0
        }
        var dynamicTimeRemaining: TimeInterval
        if adaptiveAbsorptionRateEnabled && time > adaptiveRateStandbyInterval {
            // If adaptive absorption rate is enabled, and if the time since start of absorption is greater than the standby interval, the remaining time is estimated assuming the observed relative absorption rate persists for the remaining carbs
            let dynamicAbsorptionTime = absorptionModel.absorptionTime(forPercentAbsorption: percentAbsorbed, atTime: time)
            dynamicTimeRemaining = dynamicAbsorptionTime - time
        } else {
            // If adaptive absorption rate is disabled, or if the time since start of absorption is less than the standby interval, the remaining time is estimated assuming the modeled absorption rate
            dynamicTimeRemaining = initialAbsorptionTime - timeToAbsorbObservedCarbs
        }
        // time remaining must not extend beyond the maximum absorption time
        let estimatedTimeRemaining = min(dynamicTimeRemaining, notToExceedTimeRemaining)
        return(estimatedTimeRemaining)
    }

    /// The timeline of observed absorption, if greater than the minimum required absorption.
    private var clampedTimeline: [CarbValue]? {
        return observedGrams >= minPredictedGrams ? observedTimeline : nil
    }

    /// Configures a new builder
    ///
    /// - Parameters:
    ///   - entry: The carb entry input
    ///   - carbUnit: The unit used for carb values
    ///   - carbohydrateSensitivityFactor: The carbohydrate-sensitivity factor for the entry, in glucose units per gram
    ///   - initialAbsorptionTime: The absorption initially assigned to this entry before any absorption is observed
    ///   - maxAbsorptionTime: The maximum absorption time allowed for this entry, determining the minimum absorption rate
    ///   - delay: An amount of time to wait after the entry date before minimum absorption is assumed to begin
    ///   - lastEffectDate: The last recorded date of effect observation, used to initialize absorption at model defined rate
    ///   - initialObservedEffect: The initial amount of observed effect, in glucose units. Defaults to 0.
    init(entry: T, carbUnit: HKUnit, carbohydrateSensitivityFactor: Double, initialAbsorptionTime: TimeInterval, maxAbsorptionTime: TimeInterval, delay: TimeInterval, lastEffectDate: Date?, absorptionModel: CarbAbsorptionComputable, adaptiveAbsorptionRateEnabled: Bool, adaptiveRateStandbyIntervalFraction: Double, initialObservedEffect: Double = 0) {
        self.entry = entry
        self.carbUnit = carbUnit
        self.carbohydrateSensitivityFactor = carbohydrateSensitivityFactor
        self.initialAbsorptionTime = initialAbsorptionTime
        self.maxAbsorptionTime = maxAbsorptionTime
        self.delay = delay
        self.observedEffect = initialObservedEffect
        self.absorptionModel = absorptionModel
        self.adaptiveAbsorptionRateEnabled = adaptiveAbsorptionRateEnabled
        self.adaptiveRateStandbyIntervalFraction = adaptiveRateStandbyIntervalFraction
        self.entryGrams = entry.quantity.doubleValue(for: carbUnit)
        self.entryEffect = entryGrams * carbohydrateSensitivityFactor
        self.maxEndDate = entry.startDate.addingTimeInterval(maxAbsorptionTime + delay)
        self.lastEffectDate = min(
            maxEndDate,
            Swift.max(lastEffectDate ?? entry.startDate, entry.startDate)
        )

    }

    /// Increments the builder state with the next glucose effect.
    /// 
    /// This function should only be called with values in ascending date order.
    ///
    /// - Parameters:
    ///   - effect: The effect value, in glucose units corresponding to `carbohydrateSensitivityFactor`
    ///   - start: The start date of the effect
    ///   - end: The end date of the effect
    func addNextEffect(_ effect: Double, start: Date, end: Date) {
        guard start >= entry.startDate else {
            return
        }

        observedEffect += effect

        if observedCompletionDate == nil {
            // Continue recording the timeline until 100% of the carbs have been observed
            observedTimeline.append(CarbValue(
                startDate: start,
                endDate: end,
                quantity: HKQuantity(
                    unit: carbUnit,
                    doubleValue: effect / carbohydrateSensitivityFactor
                )
            ))

            // Once 100% of the carbs are observed, track the endDate
            if observedEffect + Double(Float.ulpOfOne) >= entryEffect {
                observedCompletionDate = end
            }
        }
    }

    /// The resulting CarbStatus value
    var result: CarbStatus<T> {
        let absorption = AbsorbedCarbValue(
            observed: HKQuantity(unit: carbUnit, doubleValue: observedGrams),
            clamped: HKQuantity(unit: carbUnit, doubleValue: clampedGrams),
            total: entry.quantity,
            remaining: HKQuantity(unit: carbUnit, doubleValue: entryGrams - clampedGrams),
            observedDate: observedAbsorptionDates,
            estimatedTimeRemaining: estimatedTimeRemaining,
            timeToAbsorbObservedCarbs: timeToAbsorbObservedCarbs
        )

        return CarbStatus(
            entry: entry,
            absorption: absorption,
            observedTimeline: clampedTimeline
        )
    }
    
    func absorptionRateAtTime(t: TimeInterval) -> Double {
        let dynamicAbsorptionTime = min(observedAbsorptionDates.duration + estimatedTimeRemaining, maxAbsorptionTime)
        guard dynamicAbsorptionTime > 0 else {
            return(0.0)
        }
        // time t nomalized to absorption time
        let percentTime = t / dynamicAbsorptionTime
        let averageAbsorptionRate = entryGrams / dynamicAbsorptionTime
        return averageAbsorptionRate * absorptionModel.percentRateAtPercentTime(forPercentTime: percentTime)
    }
    
}


// MARK: - Sorted collections of CarbEntries
extension Collection where Element: CarbEntry {
    /// Maps a sorted timeline of carb entries to the observed absorbed carbohydrates for each, from a timeline of glucose effect velocities.
    ///
    /// This makes some important assumptions:
    /// - insulin effects, used with glucose to calculate counteraction, are "correct"
    /// - carbs are absorbed completely in the order they were eaten without mixing or overlapping effects
    ///
    /// - Parameters:
    ///   - effectVelocities: A timeline of glucose effect velocities, ordered by start date
    ///   - carbRatio: The schedule of carb ratios, in grams per unit
    ///   - insulinSensitivity: The schedule of insulin sensitivities, in units of insulin per glucose-unit
    ///   - absorptionTimeOverrun: A multiplier for determining the minimum absorption time from the specified absorption time
    ///   - defaultAbsorptionTime: The absorption time to use for unspecified carb entries
    ///   - delay: The time to delay the dose effect
    /// - Returns: A new array of `CarbStatus` values describing the absorbed carb quantities
    func map(
        to effectVelocities: [GlucoseEffectVelocity],
        carbRatio: CarbRatioSchedule?,
        insulinSensitivity: InsulinSensitivitySchedule?,
        absorptionTimeOverrun: Double,
        defaultAbsorptionTime: TimeInterval,
        delay: TimeInterval,
        initialAbsorptionTimeOverrun: Double,
        absorptionModel: CarbAbsorptionComputable,
        adaptiveAbsorptionRateEnabled: Bool,
        adaptiveRateStandbyIntervalFraction: Double
    ) -> [CarbStatus<Element>] {
        guard count > 0 else {
            // TODO: Apply unmatched effects to meal prediction
            return []
        }

        guard let carbRatios = carbRatio, let insulinSensitivities = insulinSensitivity else {
            return map { (entry) in
                CarbStatus(entry: entry, absorption: nil, observedTimeline: nil)
            }
        }
        
        // for computation
        let glucoseUnit = HKUnit.milligramsPerDeciliter
        let carbUnit = HKUnit.gram()

        let builders: [CarbStatusBuilder<Element>] = map { (entry) in
            let carbRatio = carbRatios.quantity(at: entry.startDate)
            let insulinSensitivity = insulinSensitivities.quantity(at: entry.startDate)
            let initialAbsorptionTimeOverrun = initialAbsorptionTimeOverrun

            return CarbStatusBuilder(
                entry: entry,
                carbUnit: carbUnit,
                carbohydrateSensitivityFactor: insulinSensitivity.doubleValue(for: glucoseUnit) / carbRatio.doubleValue(for: carbUnit), initialAbsorptionTime: (entry.absorptionTime ?? defaultAbsorptionTime) * initialAbsorptionTimeOverrun,
                maxAbsorptionTime: (entry.absorptionTime ?? defaultAbsorptionTime) * absorptionTimeOverrun,
                delay: delay,
                lastEffectDate: effectVelocities.last?.endDate,
                absorptionModel: absorptionModel,
                adaptiveAbsorptionRateEnabled: adaptiveAbsorptionRateEnabled,
                adaptiveRateStandbyIntervalFraction: adaptiveRateStandbyIntervalFraction
            )
        }

        for dxEffect in effectVelocities {
            guard dxEffect.endDate > dxEffect.startDate else {
                assertionFailure()
                continue
            }

            // calculate instantanous absorption rate for all active entries
            
            // Apply effect to all active entries

            // Select only the entries whose dates overlap the current date interval.
            // These are not necessarily contiguous as maxEndDate varies between entries
            let activeBuilders = builders.filter { (builder) -> Bool in
                return dxEffect.startDate < builder.maxEndDate && dxEffect.startDate >= builder.entry.startDate
            }

            // Ignore velocities < 0 when estimating carb absorption.
            // These are most likely the result of insulin absorption increases such as
            // during activity
            var effectValue = Swift.max(0, dxEffect.effect.quantity.doubleValue(for: glucoseUnit))

            // Sum the current absorption rates of each active entry to determine how to split the active effects
            var totalRate = activeBuilders.reduce(0) { (totalRate, builder) -> Double in
                let effectTime = dxEffect.startDate.timeIntervalSince(builder.entry.startDate)
                let absorptionRateAtEffectTime = builder.absorptionRateAtTime(t: effectTime)
                return totalRate + absorptionRateAtEffectTime
            }

            for builder in activeBuilders {
                // Apply a portion of the effect to this entry
                let effectTime = dxEffect.startDate.timeIntervalSince(builder.entry.startDate)
                let absorptionRateAtEffectTime = builder.absorptionRateAtTime(t: effectTime)
                // If total rate is zero, assign zero to partial effect
                var partialEffectValue: Double = 0.0
                if totalRate > 0 {
                    partialEffectValue = Swift.min(builder.remainingEffect, (absorptionRateAtEffectTime / totalRate) * effectValue)
                    totalRate -= absorptionRateAtEffectTime
                    effectValue -= partialEffectValue
                }

                builder.addNextEffect(partialEffectValue, start: dxEffect.startDate, end: dxEffect.endDate)

                // If there's still remainder effects with no additional entries to account them to, count them as overrun on the final entry
                if effectValue > Double(Float.ulpOfOne) && builder === activeBuilders.last! {
                    builder.addNextEffect(effectValue, start: dxEffect.startDate, end: dxEffect.endDate)
                }
            }

            // We have remaining effect and no activeBuilders (otherwise we would have applied the effect to the last one)
            if effectValue > Double(Float.ulpOfOne) {
                // TODO: Track "phantom meals"
            }
        }

        return builders.map { $0.result }
    }
}
