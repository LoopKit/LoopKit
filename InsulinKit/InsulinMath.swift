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

    /**
     Returns the percentage of total insulin effect remaining at a specified interval after delivery; also known as Insulin On Board (IOB).

     These are 4th-order polynomial fits of John Walsh's IOB curve plots, and they first appeared in GlucoDyn.

     See: https://github.com/kenstack/GlucoDyn

     - parameter time:           The interval after insulin delivery
     - parameter actionDuration: The total time of insulin effect

     - returns: The percentage of total insulin effect remaining
     */
    private static func walshPercentEffectRemainingAtTime(_ time: TimeInterval, actionDuration: TimeInterval) -> Double {

        switch time {
        case let t where t <= 0:
            return 1
        case let t where t >= actionDuration:
            return 0
        default:
            // We only have Walsh models for a few discrete action durations, so we scale other action durations appropriately to the nearest one.
            let nearestModeledDuration: TimeInterval

            switch actionDuration {
            case let x where x < TimeInterval(hours: 3):
                nearestModeledDuration = TimeInterval(hours: 3)
            case let x where x > TimeInterval(hours: 6):
                nearestModeledDuration = TimeInterval(hours: 6)
            default:
                nearestModeledDuration = TimeInterval(hours: round(actionDuration.hours))
            }

            let minutes = time.minutes * nearestModeledDuration / actionDuration

            switch nearestModeledDuration {
            case TimeInterval(hours: 3):
                return -3.2030e-9 * pow(minutes, 4) + 1.354e-6 * pow(minutes, 3) - 1.759e-4 * pow(minutes, 2) + 9.255e-4 * minutes + 0.99951
            case TimeInterval(hours: 4):
                return -3.310e-10 * pow(minutes, 4) + 2.530e-7 * pow(minutes, 3) - 5.510e-5 * pow(minutes, 2) - 9.086e-4 * minutes + 0.99950
            case TimeInterval(hours: 5):
                return -2.950e-10 * pow(minutes, 4) + 2.320e-7 * pow(minutes, 3) - 5.550e-5 * pow(minutes, 2) + 4.490e-4 * minutes + 0.99300
            case TimeInterval(hours: 6):
                return -1.493e-10 * pow(minutes, 4) + 1.413e-7 * pow(minutes, 3) - 4.095e-5 * pow(minutes, 2) + 6.365e-4 * minutes + 0.99700
            default:
                assertionFailure()
                return 0
            }
        }
    }

    private static func insulinOnBoardForContinuousDose(_ dose: DoseEntry, atDate date: Date, actionDuration: TimeInterval, delay: TimeInterval, delta: TimeInterval) -> Double {

        let doseDuration = dose.endDate.timeIntervalSince(dose.startDate as Date)  // t1
        let time = date.timeIntervalSince(dose.startDate as Date)
        var iob: Double = 0
        var doseDate = TimeInterval(0)  // i

        repeat {
            let segment = max(0, min(doseDate + delta, doseDuration) - doseDate) / doseDuration
            iob += segment * walshPercentEffectRemainingAtTime(time - delay - doseDate, actionDuration: actionDuration)
            doseDate += delta
        } while doseDate <= min(floor((time + delay) / delta) * delta, doseDuration)

        return iob
    }

    private static func insulinOnBoardForDose(_ dose: DoseEntry, atDate date: Date, actionDuration: TimeInterval, delay: TimeInterval, delta: TimeInterval) -> Double {
        let time = date.timeIntervalSince(dose.startDate as Date)
        let iob: Double

        if time >= 0 {
            if dose.unit == .units {
                iob = dose.value * walshPercentEffectRemainingAtTime(time - delay, actionDuration: actionDuration)
            } else if dose.unit == .unitsPerHour && dose.endDate.timeIntervalSince(dose.startDate as Date) <= 1.05 * delta {
                iob = dose.value * dose.endDate.timeIntervalSince(dose.startDate as Date) / TimeInterval(hours: 1) * walshPercentEffectRemainingAtTime(time - delay, actionDuration: actionDuration)
            } else {
                iob = dose.value * dose.endDate.timeIntervalSince(dose.startDate as Date) / TimeInterval(hours: 1) * insulinOnBoardForContinuousDose(dose, atDate: date, actionDuration: actionDuration, delay: delay, delta: delta)
            }
        } else {
            iob = 0
        }

        return iob
    }

    private static func glucoseEffectForContinuousDose(_ dose: DoseEntry, atDate date: Date, actionDuration: TimeInterval, delay: TimeInterval, delta: TimeInterval) -> Double {
        let doseDuration = dose.endDate.timeIntervalSince(dose.startDate as Date)  // t1
        let time = date.timeIntervalSince(dose.startDate as Date)
        var value: Double = 0
        var doseDate = TimeInterval(0)  // i

        repeat {
            let segment = max(0, min(doseDate + delta, doseDuration) - doseDate) / doseDuration
            value += segment * (1.0 - walshPercentEffectRemainingAtTime(time - delay - doseDate, actionDuration: actionDuration))
            doseDate += delta
        } while doseDate <= min(floor((time + delay) / delta) * delta, doseDuration)

        return value
    }

    private static func glucoseEffectForDose(_ dose: DoseEntry, atDate date: Date, actionDuration: TimeInterval, insulinSensitivity: Double, delay: TimeInterval, delta: TimeInterval) -> Double {
        let time = date.timeIntervalSince(dose.startDate as Date)
        let value: Double

        if time >= 0 {
            if dose.unit == .units {
                value = dose.value * -insulinSensitivity * (1.0 - walshPercentEffectRemainingAtTime(time - delay, actionDuration: actionDuration))
            } else if dose.unit == .unitsPerHour && dose.endDate.timeIntervalSince(dose.startDate as Date) <= 1.05 * delta {
                value = dose.value * -insulinSensitivity * dose.endDate.timeIntervalSince(dose.startDate as Date) / TimeInterval(hours: 1) * (1.0 - walshPercentEffectRemainingAtTime(time - delay, actionDuration: actionDuration))
            } else {
                value = dose.value * -insulinSensitivity * dose.endDate.timeIntervalSince(dose.startDate as Date) / TimeInterval(hours: 1) * glucoseEffectForContinuousDose(dose, atDate: date, actionDuration: actionDuration, delay: delay, delta: delta)
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
                let duration = value.startDate.timeIntervalSince(previousValue.startDate as Date)

                if duration > 0 && 0 <= volumeDrop && volumeDrop <= MaximumReservoirDropPerMinute * duration.minutes {
                    doses.append(DoseEntry(
                        type: .tempBasal,
                        startDate: previousValue.startDate,
                        endDate: value.startDate,
                        value: volumeDrop * TimeInterval(hours: 1) / duration,
                        unit: .unitsPerHour,
                        // TODO: Get rid of this property or properly localize it
                        description: "Reservoir decreased \(numberFormatter.string(from: NSNumber(value: volumeDrop)) ?? String(volumeDrop))U over \(numberFormatter.string(from: NSNumber(value: duration.minutes)) ?? String(duration.minutes))min"
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
    static func isContinuous<T: Collection>(_ values: T, from startDate: Date, to endDate: Date = Date(), within maximumDuration: TimeInterval = TimeInterval(minutes: 30)) -> Bool where T.Iterator.Element: ReservoirValue {

        // The first value has to be at least as old as the start date, as a reference point.
        guard let firstValue = values.first, firstValue.endDate <= startDate else {
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
        var lastTempBasal: DoseEntry?

        for dose in doses {
            switch dose.type {
            case .bolus:
                reconciled.append(dose)
            case .tempBasal:
                if let temp = lastTempBasal {
                    let endDate = min(temp.endDate, dose.startDate)

                    // Ignore 0-duration doses
                    if endDate > temp.startDate {
                        reconciled.append(DoseEntry(
                            type: temp.type,
                            startDate: temp.startDate,
                            endDate: endDate,
                            value: temp.value,
                            unit: temp.unit,
                            description: temp.description
                        ))
                    }
                }

                lastTempBasal = dose
            case .resume:
                if let suspend = lastSuspend {
                    reconciled.append(DoseEntry(
                        type: suspend.type,
                        startDate: suspend.startDate,
                        endDate: dose.endDate,
                        value: suspend.value,
                        unit: suspend.unit,
                        description: suspend.description ?? dose.description
                    ))

                    lastSuspend = nil
                }

                if let temp = lastTempBasal {
                    if temp.endDate > dose.endDate {
                        lastTempBasal = DoseEntry(
                            type: temp.type,
                            startDate: dose.endDate,
                            endDate: temp.endDate,
                            value: temp.value,
                            unit: temp.unit,
                            description: temp.description
                        )
                    } else {
                        lastTempBasal = nil
                    }
                }
            case .suspend:
                if let temp = lastTempBasal {
                    reconciled.append(DoseEntry(
                        type: temp.type,
                        startDate: temp.startDate,
                        endDate: min(temp.endDate, dose.startDate),
                        value: temp.value,
                        unit: temp.unit,
                        description: temp.description
                    ))

                    if temp.endDate <= dose.startDate {
                        lastTempBasal = nil
                    }
                }

                lastSuspend = dose
            }
        }

        if let suspend = lastSuspend {
            reconciled.append(suspend)
        } else if let temp = lastTempBasal, temp.endDate > temp.startDate {
            reconciled.append(temp)
        }

        return reconciled
    }

    private static func normalizeBasalDose(_ dose: DoseEntry, againstBasalSchedule basalSchedule: BasalRateSchedule) -> [DoseEntry] {

        var normalizedDoses: [DoseEntry] = []
        let basalItems = basalSchedule.between(start: dose.startDate, end: dose.endDate)

        for (index, basalItem) in basalItems.enumerated() {
            let value = dose.value - basalItem.value
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

            normalizedDoses.append(DoseEntry(
                type: dose.type,
                startDate: startDate,
                endDate: endDate,
                value: value,
                unit: dose.unit,
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
            if dose.unit == .unitsPerHour {
                normalizedDoses += normalizeBasalDose(dose, againstBasalSchedule: basalSchedule)
            } else {
                normalizedDoses.append(dose)
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
        var total: Double = 0

        for dose in doses {
            switch dose.unit {
            case .units:
                total += dose.value
            case .unitsPerHour:
                total += dose.value * dose.endDate.timeIntervalSince(dose.startDate as Date) / TimeInterval(hours: 1)
            }
        }

        return total
    }

    /**
     Calculates the timeline of insulin remaining for a collection of doses

     - parameter doses:          A collection of doses
     - parameter actionDuration: The total time of insulin effect
     - parameter fromDate:       The date to begin the timeline
     - parameter toDate:         The date to end the timeline
     - parameter delay:          The time to delay the dose effect
     - parameter delta:          The differential between timeline entries

     - returns: A sequence of insulin amount remaining
     */
    static func insulinOnBoardForDoses<T: Collection>(
        _ doses: T,
        actionDuration: TimeInterval,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [InsulinValue] where T.Iterator.Element == DoseEntry {
        guard let (startDate, endDate) = LoopMath.simulationDateRangeForSamples(doses, fromDate: fromDate, toDate: toDate, duration: actionDuration, delay: delay, delta: delta) else {
            return []
        }

        var date = startDate
        var values = [InsulinValue]()

        repeat {
            let value = doses.reduce(0) { (value, dose) -> Double in
                return value + insulinOnBoardForDose(dose, atDate: date, actionDuration: actionDuration, delay: delay, delta: delta)
            }

            values.append(InsulinValue(startDate: date, value: value))
            date = date.addingTimeInterval(delta)
        } while date <= endDate

        return values
    }

    /**
     Calculates the timeline of glucose effects for a collection of doses

     - parameter doses:          A collection of doses
     - parameter actionDuration: The total time of insulin effect
     - parameter fromDate:       The date to begin the timeline
     - parameter toDate:         The date to end the timeline
     - parameter delay:          The time to delay the dose effect
     - parameter delta:          The differential between timeline entries

     - returns: A sequence of glucose effects
     */
    static func glucoseEffectsForDoses<T: Collection>(
        _ doses: T,
        actionDuration: TimeInterval,
        insulinSensitivity: InsulinSensitivitySchedule,
        fromDate: Date? = nil,
        toDate: Date? = nil,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [GlucoseEffect] where T.Iterator.Element == DoseEntry {
        guard let (startDate, endDate) = LoopMath.simulationDateRangeForSamples(doses, fromDate: fromDate, toDate: toDate, duration: actionDuration, delay: delay, delta: delta) else {
            return []
        }

        var date = startDate
        var values = [GlucoseEffect]()
        let unit = HKUnit.milligramsPerDeciliterUnit()

        repeat {
            let value = doses.reduce(0) { (value, dose) -> Double in
                return value + glucoseEffectForDose(dose, atDate: date, actionDuration: actionDuration, insulinSensitivity: insulinSensitivity.quantity(at: dose.startDate).doubleValue(for: unit), delay: delay, delta: delta)
            }

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: unit, doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= endDate

        return values
    }
}
