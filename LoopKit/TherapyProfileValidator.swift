//
//  TherapyProfileValidator.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// Checks therapy profiles before they are stored or activated, for local and remote changes alike.
/// A profile that breaks any rule is rejected as a whole; values are never adjusted to fit.
public struct TherapyProfileValidator {
    public static let maximumNameLength = 32
    public static let maximumScheduleEntryCount = 48
    /// The most profiles, Default included. Nightscout refuses a profile document much larger than this allows.
    public static let maximumProfileCount = 20
    public static let scheduleSegmentInterval: TimeInterval = .minutes(30)

    /// Allowed basal rates: the pump's supported rates within the scheduled basal guardrail.
    public let supportedBasalRates: [Double]
    public let maximumBasalRatePerHour: Double?
    public let maximumBasalScheduleEntryCount: Int?
    public let suspendThreshold: GlucoseThreshold?

    public init(supportedBasalRates: [Double], maximumBasalRatePerHour: Double?, maximumBasalScheduleEntryCount: Int?, suspendThreshold: GlucoseThreshold?) {
        self.supportedBasalRates = supportedBasalRates.filter { (0.0...30.0).contains($0) }.sorted()
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.maximumBasalScheduleEntryCount = maximumBasalScheduleEntryCount
        self.suspendThreshold = suspendThreshold
    }

    // MARK: Names

    /// Checks `name` against the name rules and the other profiles' names, and returns it trimmed.
    @discardableResult
    public static func validateName(_ name: String, isDefault: Bool, existingNames: [String]) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == name else {
            throw TherapyProfileError.untrimmedName
        }
        guard !trimmed.isEmpty else {
            throw TherapyProfileError.emptyName
        }
        guard trimmed.count <= maximumNameLength else {
            throw TherapyProfileError.nameTooLong
        }
        guard !trimmed.contains(".") else {
            throw TherapyProfileError.invalidNameCharacter(".")
        }
        guard !trimmed.hasPrefix("$") else {
            throw TherapyProfileError.invalidNameCharacter("$")
        }
        if !isDefault, trimmed.caseInsensitiveCompare(TherapyProfile.defaultName) == .orderedSame {
            throw TherapyProfileError.reservedName
        }
        if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw TherapyProfileError.duplicateName(trimmed)
        }
        return trimmed
    }

    // MARK: Schedules

    /// Checks schedule start times in the order they are passed: non-empty, starting at midnight,
    /// strictly ascending, on the half-hour grid within one day, and at most 48 entries. A stored
    /// schedule's items are already sorted, so for those only duplicates fail the order check.
    public static func validateScheduleShape(startTimes: [TimeInterval], settingName: String) throws {
        guard !startTimes.isEmpty else {
            throw TherapyProfileError.invalidSchedule(String(format: LocalizedString("%1$@ has no entries", comment: "Therapy profile error: empty schedule (1: setting name)"), settingName))
        }
        guard startTimes.count <= maximumScheduleEntryCount else {
            throw TherapyProfileError.invalidSchedule(String(format: LocalizedString("%1$@ has more than %2$d entries", comment: "Therapy profile error: too many entries (1: setting name, 2: maximum)"), settingName, maximumScheduleEntryCount))
        }
        guard startTimes[0] == 0 else {
            throw TherapyProfileError.invalidSchedule(String(format: LocalizedString("%1$@ does not start at midnight", comment: "Therapy profile error: first entry not at 00:00 (1: setting name)"), settingName))
        }
        for (index, startTime) in startTimes.enumerated() {
            guard startTime >= 0, startTime < .hours(24), startTime.truncatingRemainder(dividingBy: scheduleSegmentInterval) == 0 else {
                throw TherapyProfileError.invalidSchedule(String(format: LocalizedString("%1$@ has a start time that is not on a half hour", comment: "Therapy profile error: start time off grid (1: setting name)"), settingName))
            }
            if index > 0, startTime <= startTimes[index - 1] {
                throw TherapyProfileError.invalidSchedule(String(format: LocalizedString("%1$@ start times are not in ascending order", comment: "Therapy profile error: start times not ascending (1: setting name)"), settingName))
            }
        }
    }

    /// Checks the rules that do not depend on a pump: schedule shape, the guardrails, and a correction range at or
    /// above `suspendThreshold`.
    public static func validateValues(of profile: TherapyProfile, suspendThreshold: GlucoseThreshold?) throws {
        let mgdl = LoopUnit.milligramsPerDeciliter
        guard let correctionRange = profile.glucoseTargetRangeSchedule.schedule(for: mgdl),
              let sensitivity = profile.insulinSensitivitySchedule.schedule(for: mgdl)
        else {
            throw TherapyProfileError.invalidSchedule(LocalizedString("The profile has an unsupported glucose unit", comment: "Therapy profile error: unit"))
        }

        try validateScheduleShape(startTimes: correctionRange.items.map(\.startTime), settingName: LocalizedString("Correction Range", comment: "Therapy profile schedule name: correction range"))
        try validateScheduleShape(startTimes: profile.carbRatioSchedule.items.map(\.startTime), settingName: LocalizedString("Carb Ratios", comment: "Therapy profile schedule name: carb ratios"))
        try validateScheduleShape(startTimes: profile.basalRateSchedule.items.map(\.startTime), settingName: LocalizedString("Basal Rates", comment: "Therapy profile schedule name: basal rates"))
        try validateScheduleShape(startTimes: sensitivity.items.map(\.startTime), settingName: LocalizedString("Insulin Sensitivities", comment: "Therapy profile schedule name: insulin sensitivities"))

        let targetUnit = profile.glucoseTargetRangeSchedule.unit
        let targetBounds = pickerBounds(of: Guardrail.correctionRange, in: targetUnit)
        for (item, ownItem) in zip(correctionRange.items, profile.glucoseTargetRangeSchedule.items) {
            guard item.value.minValue <= item.value.maxValue else {
                throw TherapyProfileError.invalidSchedule(LocalizedString("A correction range has its lower value above its upper value", comment: "Therapy profile error: target low above high"))
            }
            guard contains(targetBounds, ownItem.value.minValue), Self.contains(targetBounds, ownItem.value.maxValue) else {
                throw TherapyProfileError.valueOutOfRange(LocalizedString("Correction Range values are out of bounds", comment: "Therapy profile error: correction range out of bounds"))
            }
            if let suspendThreshold, item.value.minValue < suspendThreshold.quantity.doubleValue(for: mgdl) - tolerance {
                throw TherapyProfileError.correctionRangeBelowSuspendThreshold
            }
        }

        let carbRatioBounds = Guardrail.carbRatio.absoluteBounds.doubleBounds(for: .gramsPerUnit)
        for item in profile.carbRatioSchedule.items where !contains(carbRatioBounds, item.value) {
            throw TherapyProfileError.valueOutOfRange(LocalizedString("Carb Ratio values are out of bounds", comment: "Therapy profile error: carb ratio out of bounds"))
        }

        let sensitivityUnit: LoopUnit = profile.insulinSensitivitySchedule.unit == .millimolesPerLiter ? .millimolesPerLiterPerInternationalUnit : .milligramsPerDeciliterPerInternationalUnit
        let sensitivityBounds = pickerBounds(of: Guardrail.insulinSensitivity, in: sensitivityUnit)
        for item in profile.insulinSensitivitySchedule.items where !contains(sensitivityBounds, item.value) {
            throw TherapyProfileError.valueOutOfRange(LocalizedString("Insulin Sensitivity values are out of bounds", comment: "Therapy profile error: ISF out of bounds"))
        }
    }

    /// Checks every rule and returns the profile with basal rates written exactly as the pump's supported rates.
    public func validate(_ profile: TherapyProfile) throws -> TherapyProfile {
        try Self.validateValues(of: profile, suspendThreshold: suspendThreshold)

        guard !supportedBasalRates.isEmpty else {
            throw TherapyProfileError.noPump
        }
        guard let maximumBasalRatePerHour else {
            throw TherapyProfileError.maximumBasalRateNotSet
        }
        if let maximumBasalScheduleEntryCount, profile.basalRateSchedule.items.count > maximumBasalScheduleEntryCount {
            throw TherapyProfileError.invalidSchedule(String(format: LocalizedString("The pump supports at most %1$d basal rate entries", comment: "Therapy profile error: pump basal entry limit (1: maximum)"), maximumBasalScheduleEntryCount))
        }
        var basalItems: [RepeatingScheduleValue<Double>] = []
        for item in profile.basalRateSchedule.items {
            guard let supported = supportedBasalRates.first(where: { abs($0 - item.value) < Self.tolerance }) else {
                throw TherapyProfileError.unsupportedBasalRate(item.value)
            }
            guard supported <= maximumBasalRatePerHour + Self.tolerance else {
                throw TherapyProfileError.basalRateAboveMaximum(item.value)
            }
            basalItems.append(RepeatingScheduleValue(startTime: item.startTime, value: supported))
        }

        var validated = profile
        if let basal = BasalRateSchedule(dailyItems: basalItems, timeZone: profile.basalRateSchedule.timeZone) {
            validated.basalRateSchedule = basal
        }
        return validated
    }

    private static let tolerance = 1e-6

    private static func contains(_ range: ClosedRange<Double>, _ value: Double) -> Bool {
        value >= range.lowerBound - tolerance && value <= range.upperBound + tolerance
    }

    /// The lowest and highest values the guardrail's picker offers in `unit`, which rounds the bounds to the unit's
    /// digits: in mmol/L the correction range runs from 4.8 to 10.0.
    private static func pickerBounds(of guardrail: Guardrail<LoopQuantity>, in unit: LoopUnit) -> ClosedRange<Double> {
        let values = guardrail.allValues(forUnit: unit)
        guard let lowest = values.first, let highest = values.last else {
            return guardrail.absoluteBounds.doubleBounds(for: unit)
        }
        return lowest...highest
    }

    private var recommendedTargetBoundsInMilligramsPerDeciliter: ClosedRange<Double> {
        let mgdl = LoopUnit.milligramsPerDeciliter
        let absolute = Guardrail.correctionRange.absoluteBounds.doubleBounds(for: mgdl)
        let recommended = Guardrail.correctionRange.recommendedBounds.doubleBounds(for: mgdl)
        let lower = max(absolute.lowerBound, suspendThreshold?.quantity.doubleValue(for: mgdl) ?? absolute.lowerBound)
        return max(lower, recommended.lowerBound)...recommended.upperBound
    }

    // MARK: Edit limits

    /// Limits for editing profiles elsewhere, such as in a caregiver app, in `unit`.
    public func editLimits(unit: LoopUnit) -> TherapyProfileEditLimits? {
        guard let maximumBasalRatePerHour, !supportedBasalRates.isEmpty else {
            return nil
        }
        let mgdl = LoopUnit.milligramsPerDeciliter
        let glucoseStep = unit == .millimolesPerLiter ? 0.1 : 1
        func glucose(_ range: ClosedRange<Double>) -> ClosedRange<Double> {
            let lower = LoopQuantity(unit: mgdl, doubleValue: range.lowerBound).doubleValue(for: unit)
            let upper = LoopQuantity(unit: mgdl, doubleValue: range.upperBound).doubleValue(for: unit)
            return Self.onStep(lower, glucoseStep, .up)...Self.onStep(upper, glucoseStep, .down)
        }
        let targetPicker = Self.pickerBounds(of: Guardrail.correctionRange, in: unit)
        let suspendLowerBound = suspendThreshold.map { Self.onStep($0.quantity.doubleValue(for: unit), glucoseStep, .up) } ?? targetPicker.lowerBound
        let targetAbsolute = max(targetPicker.lowerBound, suspendLowerBound)...targetPicker.upperBound
        let targetRecommended = glucose(recommendedTargetBoundsInMilligramsPerDeciliter)
        let sensitivityUnit: LoopUnit = unit == .millimolesPerLiter ? .millimolesPerLiterPerInternationalUnit : .milligramsPerDeciliterPerInternationalUnit
        let sensitivityAbsolute = Self.pickerBounds(of: Guardrail.insulinSensitivity, in: sensitivityUnit)
        let sensitivityRecommended = glucose(Guardrail.insulinSensitivity.recommendedBounds.doubleBounds(for: .milligramsPerDeciliterPerInternationalUnit))
        let carbRatioAbsolute = Guardrail.carbRatio.absoluteBounds.doubleBounds(for: .gramsPerUnit)
        let carbRatioRecommended = Guardrail.carbRatio.recommendedBounds.doubleBounds(for: .gramsPerUnit)
        let basalRates = supportedBasalRates.filter { $0 <= maximumBasalRatePerHour + Self.tolerance }

        return TherapyProfileEditLimits(
            unit: unit,
            maximumBasalRatePerHour: maximumBasalRatePerHour,
            basalRates: basalRates,
            maximumBasalScheduleEntryCount: maximumBasalScheduleEntryCount,
            carbRatio: .init(bounds: carbRatioAbsolute, step: 0.1, recommended: carbRatioRecommended),
            sensitivity: .init(bounds: sensitivityAbsolute, step: glucoseStep, recommended: sensitivityRecommended),
            target: .init(bounds: targetAbsolute, step: glucoseStep, recommended: targetRecommended),
            maximumScheduleEntryCount: Self.maximumScheduleEntryCount,
            segmentInterval: Self.scheduleSegmentInterval)
    }

    private static func onStep(_ value: Double, _ step: Double, _ rule: FloatingPointRoundingRule) -> Double {
        let steps = (value / step + (rule == .up ? -1e-9 : 1e-9)).rounded(rule)
        return (steps * step * 1000).rounded() / 1000
    }
}

/// Bounds for editing profile values, as published to remote services.
public struct TherapyProfileEditLimits: Equatable {
    public struct ValueLimits: Equatable {
        public let bounds: ClosedRange<Double>
        public let step: Double
        public let recommended: ClosedRange<Double>?
    }

    public let unit: LoopUnit
    public let maximumBasalRatePerHour: Double
    /// The supported basal rates up to the maximum basal rate.
    public let basalRates: [Double]
    public let maximumBasalScheduleEntryCount: Int?
    public let carbRatio: ValueLimits
    public let sensitivity: ValueLimits
    public let target: ValueLimits
    public let maximumScheduleEntryCount: Int
    public let segmentInterval: TimeInterval
}

private extension ClosedRange where Bound == LoopQuantity {
    func doubleBounds(for unit: LoopUnit) -> ClosedRange<Double> {
        lowerBound.doubleValue(for: unit)...upperBound.doubleValue(for: unit)
    }
}
