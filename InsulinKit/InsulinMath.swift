//
//  InsulinMath.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/30/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

struct InsulinMath {

    private static func insulinOnBoardForContinuousDose(_ dose: DoseEntry, atDate date: Date, insulinModel: InsulinModel, delay: TimeInterval, delta: TimeInterval) -> Double {

        let doseDuration = dose.endDate.timeIntervalSince(dose.startDate)  // t1
        let time = date.timeIntervalSince(dose.startDate)
        var iob: Double = 0
        var doseDate = TimeInterval(0)  // i

        repeat {
            let segment = max(0, min(doseDate + delta, doseDuration) - doseDate) / doseDuration
            iob += segment * insulinModel.percentEffectRemaining(at: time - delay - doseDate)
            doseDate += delta
        } while doseDate <= min(floor((time + delay) / delta) * delta, doseDuration)

        return iob
    }

    private static func insulinOnBoardForDose(_ dose: DoseEntry, atDate date: Date, insulinModel: InsulinModel, delay: TimeInterval, delta: TimeInterval) -> Double {
        let time = date.timeIntervalSince(dose.startDate)
        let iob: Double

        if time >= 0 {
            // Consider doses within the delta time window as momentary
            if dose.endDate.timeIntervalSince(dose.startDate) <= 1.05 * delta {
                iob = dose.units * insulinModel.percentEffectRemaining(at: time - delay)
            } else {
                iob = dose.units * insulinOnBoardForContinuousDose(dose, atDate: date, insulinModel: insulinModel, delay: delay, delta: delta)
            }
        } else {
            iob = 0
        }

        return iob
    }

    private static func glucoseEffectForContinuousDose(_ dose: DoseEntry, atDate date: Date, insulinModel: InsulinModel, delay: TimeInterval, delta: TimeInterval) -> Double {
        let doseDuration = dose.endDate.timeIntervalSince(dose.startDate)  // t1
        let time = date.timeIntervalSince(dose.startDate)
        var value: Double = 0
        var doseDate = TimeInterval(0)  // i

        repeat {
            let segment = max(0, min(doseDate + delta, doseDuration) - doseDate) / doseDuration
            value += segment * (1.0 - insulinModel.percentEffectRemaining(at: time - delay - doseDate))
            doseDate += delta
        } while doseDate <= min(floor((time + delay) / delta) * delta, doseDuration)

        return value
    }

    fileprivate static func glucoseEffectForDose(_ dose: DoseEntry, atDate date: Date, insulinModel: InsulinModel, insulinSensitivity: Double, delay: TimeInterval, delta: TimeInterval) -> Double {
        let time = date.timeIntervalSince(dose.startDate)
        let value: Double

        if time >= 0 {
            // Consider doses within the delta time window as momentary
            if dose.endDate.timeIntervalSince(dose.startDate) <= 1.05 * delta {
                value = dose.units * -insulinSensitivity * (1.0 - insulinModel.percentEffectRemaining(at: time - delay))
            } else {
                value = dose.units * -insulinSensitivity * glucoseEffectForContinuousDose(dose, atDate: date, insulinModel: insulinModel, delay: delay, delta: delta)
            }
        } else {
            value = 0
        }

        return value
    }

    /**
     It takes a MM x22 pump about 40s to deliver 1 Unit while bolusing
     See: http://www.healthline.com/diabetesmine/ask-dmine-speed-insulin-pumps#3
     
     The x23 and newer pumps can deliver at 2x, 3x, and 4x that speed, targeting
     a maximum 5-minute delivery for all boluses (8U - 25U)
     
     A basal rate of 30 U/hour (near-max) would deliver an additional 0.5 U/min.
     */
    private static let MaximumReservoirDropPerMinute = 6.5

    /**
     Converts a continuous sequence of reservoir values to a sequence of doses

     - parameter values: A collection of reservoir values, in chronological order

     - returns: An array of doses
     */
    static func doseEntriesFromReservoirValues<T: Collection>(_ values: T) -> [DoseEntry] where T.Iterator.Element: ReservoirValue {

        var doses: [DoseEntry] = []
        var previousValue: T.Iterator.Element?

        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 3

        for value in values {
            if let previousValue = previousValue {
                let volumeDrop = previousValue.unitVolume - value.unitVolume
                let duration = value.startDate.timeIntervalSince(previousValue.startDate)

                if duration > 0 && 0 <= volumeDrop && volumeDrop <= MaximumReservoirDropPerMinute * duration.minutes {
                    doses.append(DoseEntry(
                        type: .tempBasal,
                        startDate: previousValue.startDate,
                        endDate: value.startDate,
                        value: volumeDrop,
                        unit: .units
                    ))
                }
            }

            previousValue = value
        }

        return doses
    }

    /**
     Whether a span of reservoir values is considered continuous and therefore reliable.
     
     Reservoir values of 0 are automatically considered unreliable due to the assumption that an unknown amount of insulin can be delivered after the 0 marker.

     - parameter entries:         A collection of reservoir values, in chronological order
     - parameter startDate:       The beginning of the interval in which to validate continuity
     - parameter endDate:         The end of the interval in which to validate continuity
     - parameter maximumDuration: The maximum interval to consider reliable for a reservoir-derived dose
     
     - returns: Whether the reservoir values meet the critera for continuity
     */
    static func isContinuous<T: Collection>(_ values: T, from startDate: Date? = nil, to endDate: Date = Date(), within maximumDuration: TimeInterval = TimeInterval(minutes: 30)) -> Bool where T.Iterator.Element: ReservoirValue {
        guard let firstValue = values.first else {
            return false
        }

        // The first value has to be at least as old as the start date, as a reference point.
        let startDate = startDate ?? firstValue.endDate
        guard firstValue.endDate <= startDate else {
            return false
        }

        var lastValue = firstValue

        for value in values {
            defer {
                lastValue = value
            }

            // Volume and interval validation only applies for values in the specified range,
            guard value.endDate >= startDate && value.startDate <= endDate else {
                continue
            }

            // We can't trust 0. What else was delivered?
            guard value.unitVolume > 0 else {
                return false
            }

            // Rises in reservoir volume indicate a rewind + prime, and primes
            // can be easily confused with boluses.
            // Small rises (1 U) can be ignored as they're indicative of a mixed-precision sequence.
            guard value.unitVolume <= lastValue.unitVolume + 1 else {
                return false
            }

            // Ensure no more than the maximum interval has passed
            guard value.startDate.timeIntervalSince(lastValue.endDate) <= maximumDuration else {
                return false
            }
        }

        return true
    }

    /**
     Maps a timeline of dose entries with overlapping start and end dates to a timeline of doses that represents actual insulin delivery.

     - parameter doses:     A timeline of dose entries, in chronological order

     - returns: An array of reconciled insulin delivery history, as TempBasal and Bolus records
     */
    static func reconcileDoses<T: Collection>(_ doses: T) -> [DoseEntry] where T.Iterator.Element == DoseEntry {

        var reconciled: [DoseEntry] = []

        var lastSuspend: DoseEntry?
        var lastBasal: DoseEntry?

        for dose in doses {
            switch dose.type {
            case .bolus:
                reconciled.append(dose)
            case .basal:
                // A basal start can indicate a resume in the case of a rewind
                if let suspend = lastSuspend {
                    reconciled.append(DoseEntry(
                        type: suspend.type,
                        startDate: suspend.startDate,
                        endDate: dose.startDate,
                        value: suspend.value,
                        unit: suspend.unit,
                        description: suspend.description ?? dose.description
                    ))

                    lastSuspend = nil
                }

                fallthrough  // Reconcile scheduled basals along with temporary
            case .tempBasal:
                if let last = lastBasal {
                    let endDate = min(last.endDate, dose.startDate)

                    // Ignore 0-duration doses
                    if endDate > last.startDate {
                        reconciled.append(DoseEntry(
                            type: last.type,
                            startDate: last.startDate,
                            endDate: endDate,
                            value: last.value,
                            unit: last.unit,
                            description: last.description
                        ))
                    }
                }

                lastBasal = dose
            case .resume:
                if let suspend = lastSuspend {
                    reconciled.append(DoseEntry(
                        type: suspend.type,
                        startDate: suspend.startDate,
                        endDate: dose.startDate,
                        value: suspend.value,
                        unit: suspend.unit,
                        description: suspend.description ?? dose.description
                    ))

                    lastSuspend = nil
                }

                // Continue temp basals that may have started before suspending
                if let last = lastBasal, last.type == .tempBasal {
                    if last.endDate > dose.endDate {
                        lastBasal = DoseEntry(
                            type: last.type,
                            startDate: dose.endDate,
                            endDate: last.endDate,
                            value: last.value,
                            unit: last.unit,
                            description: last.description
                        )
                    } else {
                        lastBasal = nil
                    }
                }
            case .suspend:
                if let last = lastBasal {
                    reconciled.append(DoseEntry(
                        type: last.type,
                        startDate: last.startDate,
                        endDate: min(last.endDate, dose.startDate),
                        value: last.value,
                        unit: last.unit,
                        description: last.description
                    ))

                    if last.endDate <= dose.startDate {
                        lastBasal = nil
                    }
                }

                lastSuspend = dose
            }
        }

        if let suspend = lastSuspend {
            reconciled.append(suspend)
        } else if let last = lastBasal, last.endDate > last.startDate {
            reconciled.append(last)
        }

        return reconciled
    }

    private static func normalizeBasalDose(_ dose: DoseEntry, againstBasalSchedule basalSchedule: BasalRateSchedule) -> [DoseEntry] {

        var normalizedDoses: [DoseEntry] = []
        let basalItems = basalSchedule.between(start: dose.startDate, end: dose.endDate)

        for (index, basalItem) in basalItems.enumerated() {
            let unitsPerHour = dose.unitsPerHour - basalItem.value
            let startDate: Date
            let endDate: Date

            if index == 0 {
                startDate = dose.startDate
            } else {
                startDate = basalItem.startDate
            }

            if index == basalItems.count - 1 {
                endDate = dose.endDate
            } else {
                endDate = basalItems[index + 1].startDate
            }

            // Ignore net-zero basals
            guard abs(unitsPerHour) > .ulpOfOne else {
                continue
            }

            normalizedDoses.append(DoseEntry(
                type: dose.type,
                startDate: startDate,
                endDate: endDate,
                value: unitsPerHour,
                unit: .unitsPerHour,
                description: dose.description
            ))
        }

        return normalizedDoses
    }

    /**
     Normalizes a sequence of dose entries against a basal rate schedule to a new sequence where each TempBasal value is relative to the scheduled basal value during that time period.

     Doses which cross boundaries in the basal rate schedule are split into multiple entries.

     - parameter doses:         A sequence of dose entries
     - parameter basalSchedule: The basal rate schedule to normalize against

     - returns: An array of normalized dose entries
     */
    static func normalize<T: Collection>(_ doses: T, againstBasalSchedule basalSchedule: BasalRateSchedule) -> [DoseEntry] where T.Iterator.Element == DoseEntry {

        var normalizedDoses: [DoseEntry] = []

        for dose in doses {
            switch dose.type {
            case .tempBasal, .suspend, .resume:
                normalizedDoses += normalizeBasalDose(dose, againstBasalSchedule: basalSchedule)
            case .bolus:
                normalizedDoses.append(dose)
            case .basal:
                break
            }
        }

        return normalizedDoses
    }

    /**
     Calculates the total insulin delivery for a collection of doses

     - parameter values: A collection of doses

     - returns: The total insulin insulin, in Units
     */
    static func totalDeliveryForDoses<T: Collection>(_ doses: T) -> Double where T.Iterator.Element == DoseEntry {
        return doses.reduce(0) { (total, dose) -> Double in
            return total + dose.units
        }
    }

    /**
     Calculates the timeline of insulin remaining for a collection of doses

     - parameter doses:          A collection of doses
     - parameter insulinModel:   The model of insulin activity over time
     - parameter start:          The date to begin the timeline
     - parameter end:            The date to end the timeline
     - parameter delay:          The time to delay the dose effect
     - parameter delta:          The differential between timeline entries

     - returns: A sequence of insulin amount remaining
     */
    static func insulinOnBoardForDoses<T: Collection>(
        _ doses: T,
        insulinModel: InsulinModel,
        from start: Date? = nil,
        to end: Date? = nil,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [InsulinValue] where T.Iterator.Element == DoseEntry {
        guard let (start, end) = LoopMath.simulationDateRangeForSamples(doses, from: start, to: end, duration: insulinModel.effectDuration, delay: delay, delta: delta) else {
            return []
        }

        var date = start
        var values = [InsulinValue]()

        repeat {
            let value = doses.reduce(0) { (value, dose) -> Double in
                return value + insulinOnBoardForDose(dose, atDate: date, insulinModel: insulinModel, delay: delay, delta: delta)
            }

            values.append(InsulinValue(startDate: date, value: value))
            date = date.addingTimeInterval(delta)
        } while date <= end

        return values
    }

    static func trimContinuingDoses<T: Collection>(_ doses: T, endDate: Date?) -> [DoseEntry] where T.Iterator.Element == DoseEntry {
        return doses.map {
            if let endDate = endDate, $0.type == .tempBasal, $0.endDate > endDate {
                return DoseEntry(
                    type: $0.type,
                    startDate: $0.startDate,
                    endDate: endDate,
                    value: $0.value,
                    unit: $0.unit,
                    description: $0.description)
            } else {
                return $0
            }
        }
    }
}


extension Collection where Iterator.Element == DoseEntry {
    /// Calculates the timeline of glucose effects for a collection of doses
    ///
    /// - Parameters:
    ///   - insulinModel: The model of insulin activity over time
    ///   - insulinSensitivity: The schedule of glucose effect per unit of insulin
    ///   - start: The earliest date of effects to return
    ///   - end: The latest date of effects to return
    ///   - delay: The time after a dose to begin its modeled effects
    ///   - delta: The interval between returned effects
    /// - Returns: An array of glucose effects for the duration of the doses
    public func glucoseEffects(
        insulinModel: InsulinModel,
        insulinSensitivity: InsulinSensitivitySchedule,
        from start: Date? = nil,
        to end: Date? = nil,
        delay: TimeInterval = TimeInterval(/* minutes: */60 * 10),
        delta: TimeInterval = TimeInterval(/* minutes: */60 * 5)
    ) -> [GlucoseEffect] {
        guard let (start, end) = LoopMath.simulationDateRangeForSamples(self, from: start, to: end, duration: insulinModel.effectDuration, delay: delay, delta: delta) else {
            return []
        }

        var date = start
        var values = [GlucoseEffect]()
        let unit = HKUnit.milligramsPerDeciliter()

        repeat {
            let value = reduce(0) { (value, dose) -> Double in
                return value + InsulinMath.glucoseEffectForDose(dose, atDate: date, insulinModel: insulinModel, insulinSensitivity: insulinSensitivity.quantity(at: dose.startDate).doubleValue(for: unit), delay: delay, delta: delta)
            }

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: unit, doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= end

        return values
    }
}

