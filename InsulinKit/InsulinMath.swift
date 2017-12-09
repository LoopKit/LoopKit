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


extension DoseEntry {
    private func continuousDeliveryInsulinOnBoard(at date: Date, model: InsulinModel, delay: TimeInterval, delta: TimeInterval) -> Double {
        let doseDuration = endDate.timeIntervalSince(startDate)  // t1
        let time = date.timeIntervalSince(startDate)
        var iob: Double = 0
        var doseDate = TimeInterval(0)  // i

        repeat {
            let segment: Double

            if doseDuration > 0 {
                segment = max(0, min(doseDate + delta, doseDuration) - doseDate) / doseDuration
            } else {
                segment = 1
            }

            iob += segment * model.percentEffectRemaining(at: time - delay - doseDate)
            doseDate += delta
        } while doseDate <= min(floor((time + delay) / delta) * delta, doseDuration)

        return iob
    }

    func insulinOnBoard(at date: Date, model: InsulinModel, delay: TimeInterval, delta: TimeInterval) -> Double {
        let time = date.timeIntervalSince(startDate)
        guard time >= 0 else {
            return 0
        }

        // Consider doses within the delta time window as momentary
        if endDate.timeIntervalSince(startDate) <= 1.05 * delta {
            return units * model.percentEffectRemaining(at: time - delay)
        } else {
            return units * continuousDeliveryInsulinOnBoard(at: date, model: model, delay: delay, delta: delta)
        }
    }

    private func continuousDeliveryGlucoseEffect(at date: Date, model: InsulinModel, delay: TimeInterval, delta: TimeInterval) -> Double {
        let doseDuration = endDate.timeIntervalSince(startDate)  // t1
        let time = date.timeIntervalSince(startDate)
        var value: Double = 0
        var doseDate = TimeInterval(0)  // i

        repeat {
            let segment: Double

            if doseDuration > 0 {
                segment = max(0, min(doseDate + delta, doseDuration) - doseDate) / doseDuration
            } else {
                segment = 1
            }

            value += segment * (1.0 - model.percentEffectRemaining(at: time - delay - doseDate))
            doseDate += delta
        } while doseDate <= min(floor((time + delay) / delta) * delta, doseDuration)

        return value
    }

    func glucoseEffect(at date: Date, model: InsulinModel, insulinSensitivity: Double, delay: TimeInterval, delta: TimeInterval) -> Double {
        let time = date.timeIntervalSince(startDate)

        guard time >= 0 else {
            return 0
        }

        // Consider doses within the delta time window as momentary
        if endDate.timeIntervalSince(startDate) <= 1.05 * delta {
            return units * -insulinSensitivity * (1.0 - model.percentEffectRemaining(at: time - delay))
        } else {
            return units * -insulinSensitivity * continuousDeliveryGlucoseEffect(at: date, model: model, delay: delay, delta: delta)
        }
    }

    func trim(to end: Date?) -> DoseEntry {
        if let end = end, unit == .unitsPerHour, endDate > end {
            return DoseEntry(
                type: type,
                startDate: startDate,
                endDate: end,
                value: value,
                unit: unit,
                description: description
            )
        } else {
            return self
        }
    }
}


/**
 It takes a MM x22 pump about 40s to deliver 1 Unit while bolusing
 See: http://www.healthline.com/diabetesmine/ask-dmine-speed-insulin-pumps#3

 The x23 and newer pumps can deliver at 2x, 3x, and 4x that speed, targeting
 a maximum 5-minute delivery for all boluses (8U - 25U)

 A basal rate of 30 U/hour (near-max) would deliver an additional 0.5 U/min.
 */
private let MaximumReservoirDropPerMinute = 6.5


extension Collection where Element: ReservoirValue {
    /**
     Converts a continuous, chronological sequence of reservoir values to a sequence of doses

     This is an O(n) operation.

     - returns: An array of doses
     */
    var doseEntries: [DoseEntry] {
        var doses: [DoseEntry] = []
        var previousValue: Element?

        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.maximumFractionDigits = 3

        for value in self {
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
     Whether a span of chronological reservoir values is considered continuous and therefore reliable.
     
     Reservoir values of 0 are automatically considered unreliable due to the assumption that an unknown amount of insulin can be delivered after the 0 marker.

     - parameter startDate:       The beginning of the interval in which to validate continuity
     - parameter endDate:         The end of the interval in which to validate continuity
     - parameter maximumDuration: The maximum interval to consider reliable for a reservoir-derived dose
     
     - returns: Whether the reservoir values meet the critera for continuity
     */
    func isContinuous(from start: Date?, to end: Date, within maximumDuration: TimeInterval) -> Bool {
        guard let firstValue = self.first else {
            return false
        }

        // The first value has to be at least as old as the start date, as a reference point.
        let startDate = start ?? firstValue.endDate
        guard firstValue.endDate <= startDate else {
            return false
        }

        var lastValue = firstValue

        for value in self {
            defer {
                lastValue = value
            }

            // Volume and interval validation only applies for values in the specified range,
            guard value.endDate >= startDate && value.startDate <= end else {
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
}


extension DoseEntry {
    fileprivate func normalize(against basalSchedule: BasalRateSchedule) -> [DoseEntry] {
        var normalizedDoses: [DoseEntry] = []
        let basalItems = basalSchedule.between(start: startDate, end: endDate)

        for (index, basalItem) in basalItems.enumerated() {
            let unitsPerHour = self.unitsPerHour - basalItem.value
            let startDate: Date
            let endDate: Date

            if index == 0 {
                startDate = self.startDate
            } else {
                startDate = basalItem.startDate
            }

            if index == basalItems.count - 1 {
                endDate = self.endDate
            } else {
                endDate = basalItems[index + 1].startDate
            }

            // Ignore net-zero basals
            guard abs(unitsPerHour) > .ulpOfOne else {
                continue
            }

            normalizedDoses.append(DoseEntry(
                type: type,
                startDate: startDate,
                endDate: endDate,
                value: unitsPerHour,
                unit: .unitsPerHour,
                description: description
            ))
        }

        return normalizedDoses
    }
}

extension Collection where Iterator.Element == DoseEntry {

    /**
     Maps a timeline of dose entries with overlapping start and end dates to a timeline of doses that represents actual insulin delivery.

     - returns: An array of reconciled insulin delivery history, as TempBasal and Bolus records
     */
    func reconcile() -> [DoseEntry] {

        var reconciled: [DoseEntry] = []

        var lastSuspend: DoseEntry?
        var lastBasal: DoseEntry?

        for dose in self {
            switch dose.type {
            case .bolus:
                reconciled.append(dose)
            case .basal, .tempBasal:
                if let last = lastBasal {
                    let endDate = Swift.min(last.endDate, dose.startDate)

                    // Ignore 0-duration doses
                    if endDate > last.startDate {
                        reconciled.append(DoseEntry(
                            type: last.type,
                            startDate: last.startDate,
                            endDate: endDate,
                            value: last.value,
                            unit: last.unit,
                            description: last.description,
                            syncIdentifier: last.syncIdentifier,
                            managedObjectID: nil
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
                        description: suspend.description ?? dose.description,
                        syncIdentifier: suspend.syncIdentifier,
                        managedObjectID: nil
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
                            description: last.description,
                            // We intentionally use the resume's identifier as the basal entry has already been entered
                            syncIdentifier: dose.syncIdentifier,
                            managedObjectID: nil
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
                        endDate: Swift.min(last.endDate, dose.startDate),
                        value: last.value,
                        unit: last.unit,
                        description: last.description,
                        syncIdentifier: last.syncIdentifier,
                        managedObjectID: nil
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

    /**
     Normalizes a sequence of dose entries against a basal rate schedule to a new sequence where each TempBasal value is relative to the scheduled basal value during that time period.

     Doses which cross boundaries in the basal rate schedule are split into multiple entries.

     - parameter basalSchedule: The basal rate schedule to normalize against

     - returns: An array of normalized dose entries
     */
    func normalize(against basalSchedule: BasalRateSchedule) -> [DoseEntry] {
        var normalizedDoses: [DoseEntry] = []

        for dose in self {
            switch dose.type {
            case .tempBasal, .suspend, .resume:
                normalizedDoses += dose.normalize(against: basalSchedule)
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

     - returns: The total insulin insulin, in Units
     */
    var totalDelivery: Double {
        return reduce(0) { (total, dose) -> Double in
            return total + dose.units
        }
    }

    /**
     Calculates the timeline of insulin remaining for a collection of doses

     - parameter insulinModel:   The model of insulin activity over time
     - parameter start:          The date to begin the timeline
     - parameter end:            The date to end the timeline
     - parameter delay:          The time to delay the dose effect
     - parameter delta:          The differential between timeline entries

     - returns: A sequence of insulin amount remaining
     */
    func insulinOnBoard(
        model: InsulinModel,
        from start: Date? = nil,
        to end: Date? = nil,
        delay: TimeInterval = TimeInterval(minutes: 10),
        delta: TimeInterval = TimeInterval(minutes: 5)
    ) -> [InsulinValue] {
        guard let (start, end) = LoopMath.simulationDateRangeForSamples(self, from: start, to: end, duration: model.effectDuration, delay: delay, delta: delta) else {
            return []
        }

        var date = start
        var values = [InsulinValue]()

        repeat {
            let value = reduce(0) { (value, dose) -> Double in
                return value + dose.insulinOnBoard(at: date, model: model, delay: delay, delta: delta)
            }

            values.append(InsulinValue(startDate: date, value: value))
            date = date.addingTimeInterval(delta)
        } while date <= end

        return values
    }

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
                return value + dose.glucoseEffect(at: date, model: insulinModel, insulinSensitivity: insulinSensitivity.quantity(at: dose.startDate).doubleValue(for: unit), delay: delay, delta: delta)
            }

            values.append(GlucoseEffect(startDate: date, quantity: HKQuantity(unit: unit, doubleValue: value)))
            date = date.addingTimeInterval(delta)
        } while date <= end

        return values
    }

    /// Applies the current basal schedule to a collection of reconciled doses in chronological order
    ///
    /// The scheduled basal rate is associated doses that override it, for later derivation of net delivery
    ///
    /// - Parameters:
    ///   - basalSchedule: The active basal schedule during the dose delivery
    ///   - start: The earliest date to apply the basal schedule
    ///   - end: The latest date to include. Doses must end before this time to be included.
    ///   - insertingBasalEntries: Whether basal doses should be created from the schedule. Pass true only for pump models that do not report their basal rates in event history.
    /// - Returns: An array of doses, 
    @available(iOS 11.0, *)
    func overlayBasalSchedule(_ basalSchedule: BasalRateSchedule, startingAt start: Date, endingAt end: Date, insertingBasalEntries: Bool) -> [DoseEntry] {
        let dateFormatter = ISO8601DateFormatter()  // GMT-based ISO formatting
        let perHour = HKUnit.internationalUnit().unitDivided(by: .hour())
        var newEntries = [DoseEntry]()
        var lastBasal: DoseEntry?

        if insertingBasalEntries {
            // Create a placeholder entry at our start date, so we know the correct duration of the
            // inserted basal entries
            lastBasal = DoseEntry(resumeDate: start)
        }

        for dose in self {
            switch dose.type {
            case .tempBasal, .basal, .suspend:
                // Only include entries if they have ended by the end date, since they may be cancelled
                guard dose.endDate <= end else {
                    continue
                }

                if let lastBasal = lastBasal {
                    if insertingBasalEntries {
                        // For older pumps which don't report the start/end of scheduled basal delivery,
                        // generate a basal entry from the specified schedule.
                        for scheduled in basalSchedule.between(start: lastBasal.endDate, end: dose.startDate) {
                            // Generate a unique identifier based on the start/end timestamps
                            let start = Swift.max(lastBasal.endDate, scheduled.startDate)
                            let end = Swift.min(dose.startDate, scheduled.endDate)

                            guard end.timeIntervalSince(start) > .ulpOfOne else {
                                continue
                            }

                            let syncIdentifier = "BasalRateSchedule \(dateFormatter.string(from: start)) \(dateFormatter.string(from: end))"

                            newEntries.append(DoseEntry(
                                type: .basal,
                                startDate: start,
                                endDate: end,
                                value: scheduled.value,
                                unit: .unitsPerHour,
                                syncIdentifier: syncIdentifier,
                                managedObjectID: nil
                            ))
                        }
                    }
                }

                if case .basal = dose.type {
                    lastBasal = dose
                } else {
                    // Associate the scheduled rate to temp basal and suspend windows
                    var tempBasal = dose
                    tempBasal.scheduledBasalRate = HKQuantity(unit: perHour, doubleValue: basalSchedule.value(at: dose.startDate))
                    lastBasal = tempBasal
                }

                // Only include the last basal entry if has ended by our end date
                if let lastBasal = lastBasal {
                    newEntries.append(lastBasal)
                }
            case .resume:
                assertionFailure("No resume events should be present in reconciled doses")
            case .bolus:
                newEntries.append(dose)
            }
        }

        return newEntries
    }
}
