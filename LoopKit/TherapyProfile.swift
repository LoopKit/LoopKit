//
//  TherapyProfile.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import CryptoKit
import Foundation

/// A named set of the four scheduled therapy settings: correction range, carb ratios, basal rates and
/// insulin sensitivities. The live schedules Loop doses with always equal the active profile's.
public struct TherapyProfile: Codable, Equatable {
    /// The profile that always exists. It is active when no other profile is.
    public static let defaultName = "Default"

    public var name: String
    public var glucoseTargetRangeSchedule: GlucoseRangeSchedule
    public var carbRatioSchedule: CarbRatioSchedule
    public var basalRateSchedule: BasalRateSchedule
    public var insulinSensitivitySchedule: InsulinSensitivitySchedule

    /// The correction range keeps its unit, daily items and time zone, and no override.
    public init(name: String,
                glucoseTargetRangeSchedule: GlucoseRangeSchedule,
                carbRatioSchedule: CarbRatioSchedule,
                basalRateSchedule: BasalRateSchedule,
                insulinSensitivitySchedule: InsulinSensitivitySchedule) {
        self.name = name
        self.glucoseTargetRangeSchedule = GlucoseRangeSchedule(unit: glucoseTargetRangeSchedule.unit,
                                                               dailyItems: glucoseTargetRangeSchedule.items,
                                                               timeZone: glucoseTargetRangeSchedule.timeZone) ?? glucoseTargetRangeSchedule
        self.carbRatioSchedule = carbRatioSchedule
        self.basalRateSchedule = basalRateSchedule
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
    }

    /// A profile from live schedules, or nil when any of them is missing.
    public init?(name: String,
                 glucoseTargetRangeSchedule: GlucoseRangeSchedule?,
                 carbRatioSchedule: CarbRatioSchedule?,
                 basalRateSchedule: BasalRateSchedule?,
                 insulinSensitivitySchedule: InsulinSensitivitySchedule?) {
        guard let glucoseTargetRangeSchedule, let carbRatioSchedule, let basalRateSchedule, let insulinSensitivitySchedule else {
            return nil
        }
        self.init(name: name,
                  glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
                  carbRatioSchedule: carbRatioSchedule,
                  basalRateSchedule: basalRateSchedule,
                  insulinSensitivitySchedule: insulinSensitivitySchedule)
    }

    public var isDefault: Bool {
        name == TherapyProfile.defaultName
    }

    /// True when both profiles hold the same schedule values, ignoring name, glucose unit and time zone.
    public func hasSameValues(as other: TherapyProfile) -> Bool {
        let unit = LoopUnit.milligramsPerDeciliter
        return glucoseTargetRangeSchedule.schedule(for: unit)?.items.roundedRanges == other.glucoseTargetRangeSchedule.schedule(for: unit)?.items.roundedRanges &&
            carbRatioSchedule.items == other.carbRatioSchedule.items &&
            basalRateSchedule.items == other.basalRateSchedule.items &&
            insulinSensitivitySchedule.schedule(for: unit)?.items.roundedValues == other.insulinSensitivitySchedule.schedule(for: unit)?.items.roundedValues
    }

    /// This profile with every schedule in `timeZone`.
    public func withTimeZone(_ timeZone: TimeZone) -> TherapyProfile {
        var profile = self
        profile.glucoseTargetRangeSchedule.timeZone = timeZone
        profile.carbRatioSchedule.timeZone = timeZone
        profile.basalRateSchedule.timeZone = timeZone
        profile.insulinSensitivitySchedule.timeZone = timeZone
        return profile
    }

    /// This profile with each correction range bound and insulin sensitivity taken from `stored` where `stored` has the
    /// same start time and the same value to the three decimals `hasSameValues(as:)` compares in mg/dL, so a value that
    /// is sent back unchanged stays exactly as stored. The glucose schedules are in `stored`'s unit.
    public func keepingStoredGlucoseValues(of stored: TherapyProfile) -> TherapyProfile {
        let mgdL = LoopUnit.milligramsPerDeciliter
        let rangeUnit = stored.glucoseTargetRangeSchedule.unit
        let sensitivityUnit = stored.insulinSensitivitySchedule.unit
        guard let range = glucoseTargetRangeSchedule.schedule(for: rangeUnit),
              let rangeMgdL = glucoseTargetRangeSchedule.schedule(for: mgdL)?.items,
              let storedRangeMgdL = stored.glucoseTargetRangeSchedule.schedule(for: mgdL)?.items,
              let sensitivity = insulinSensitivitySchedule.schedule(for: sensitivityUnit),
              let sensitivityMgdL = insulinSensitivitySchedule.schedule(for: mgdL)?.items,
              let storedSensitivityMgdL = stored.insulinSensitivitySchedule.schedule(for: mgdL)?.items
        else {
            return self
        }
        func same(_ a: Double, _ b: Double) -> Bool {
            String(format: "%.3f", a) == String(format: "%.3f", b)
        }
        let rangeItems = range.items.enumerated().map { index, item -> RepeatingScheduleValue<DoubleRange> in
            guard let storedIndex = storedRangeMgdL.firstIndex(where: { $0.startTime == item.startTime }) else {
                return item
            }
            let storedItem = stored.glucoseTargetRangeSchedule.items[storedIndex].value
            let minValue = same(storedRangeMgdL[storedIndex].value.minValue, rangeMgdL[index].value.minValue) ? storedItem.minValue : item.value.minValue
            let maxValue = same(storedRangeMgdL[storedIndex].value.maxValue, rangeMgdL[index].value.maxValue) ? storedItem.maxValue : item.value.maxValue
            return RepeatingScheduleValue(startTime: item.startTime, value: DoubleRange(minValue: minValue, maxValue: maxValue))
        }
        let sensitivityItems = sensitivity.items.enumerated().map { index, item -> RepeatingScheduleValue<Double> in
            guard let storedIndex = storedSensitivityMgdL.firstIndex(where: { $0.startTime == item.startTime }),
                  same(storedSensitivityMgdL[storedIndex].value, sensitivityMgdL[index].value)
            else {
                return item
            }
            return stored.insulinSensitivitySchedule.items[storedIndex]
        }
        var profile = self
        if let keptRange = GlucoseRangeSchedule(unit: rangeUnit, dailyItems: rangeItems, timeZone: range.timeZone) {
            profile.glucoseTargetRangeSchedule = keptRange
        }
        if let keptSensitivity = InsulinSensitivitySchedule(unit: sensitivityUnit, dailyItems: sensitivityItems, timeZone: sensitivity.timeZone) {
            profile.insulinSensitivitySchedule = keptSensitivity
        }
        return profile
    }

    /// This profile with its glucose schedules in `unit`.
    public func withGlucoseUnit(_ unit: LoopUnit) -> TherapyProfile {
        var profile = self
        if let range = glucoseTargetRangeSchedule.schedule(for: unit) {
            profile.glucoseTargetRangeSchedule = range
        }
        if let sensitivity = insulinSensitivitySchedule.schedule(for: unit) {
            profile.insulinSensitivitySchedule = sensitivity
        }
        return profile
    }
}

// MARK: - Fingerprint

extension TherapyProfile {
    /// The value a follower computes from the uploaded profile and sends with a remote command, so the phone only acts
    /// on the values the follower reviewed. Canonical form, with glucose values in `unit` and every value to three
    /// decimals: `basal=<seconds>:<value>,...;carbratio=...;sens=...;target_low=...;target_high=...`, hashed with
    /// SHA-256, first 16 hex characters. Nil when a glucose schedule has no values in `unit`.
    public func fingerprint(unit: LoopUnit) -> String? {
        canonicalFingerprintString(unit: unit).map(Self.fingerprint(canonical:))
    }

    /// True when this profile has `fingerprint` in either glucose unit.
    public func matches(fingerprint: String) -> Bool {
        [LoopUnit.milligramsPerDeciliter, .millimolesPerLiter].contains {
            self.fingerprint(unit: $0) == fingerprint
        }
    }

    func canonicalFingerprintString(unit: LoopUnit) -> String? {
        guard let correctionRange = glucoseTargetRangeSchedule.schedule(for: unit),
              let sensitivity = insulinSensitivitySchedule.schedule(for: unit)
        else {
            return nil
        }
        func items(_ schedule: [(startTime: TimeInterval, value: Double)]) -> String {
            schedule.map { "\(Int($0.startTime)):" + String(format: "%.3f", $0.value) }.joined(separator: ",")
        }
        return [
            "basal=" + items(basalRateSchedule.items.map { ($0.startTime, $0.value) }),
            "carbratio=" + items(carbRatioSchedule.items.map { ($0.startTime, $0.value) }),
            "sens=" + items(sensitivity.items.map { ($0.startTime, $0.value) }),
            "target_low=" + items(correctionRange.items.map { ($0.startTime, $0.value.minValue) }),
            "target_high=" + items(correctionRange.items.map { ($0.startTime, $0.value.maxValue) }),
        ].joined(separator: ";")
    }

    static func fingerprint(canonical: String) -> String {
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }
}

private extension Array where Element == RepeatingScheduleValue<DoubleRange> {
    var roundedRanges: [String] {
        map { String(format: "%.0f:%.3f-%.3f", $0.startTime, $0.value.minValue, $0.value.maxValue) }
    }
}

private extension Array where Element == RepeatingScheduleValue<Double> {
    var roundedValues: [String] {
        map { String(format: "%.0f:%.3f", $0.startTime, $0.value) }
    }
}

// MARK: - Profile sets

public enum TherapyProfileError: LocalizedError, Equatable {
    case emptyName
    case untrimmedName
    case nameTooLong
    case invalidNameCharacter(String)
    case reservedName
    case duplicateName(String)
    case tooManyProfiles
    case notFound(String)
    case cannotDeleteActive
    case cannotDeleteDefault
    case cannotRenameDefault
    case conflict
    case noPump
    case maximumBasalRateNotSet
    case operationInProgress
    case pumpSyncFailed(String)
    case pumpSuspended
    case activeProfileChangedWhileEditing(String)
    case settingsChangedWhileEditing
    case invalidSchedule(String)
    case valueOutOfRange(String)
    case unsupportedBasalRate(Double)
    case basalRateAboveMaximum(Double)
    case correctionRangeBelowSuspendThreshold

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return LocalizedString("The profile name is empty", comment: "Therapy profile error: empty name")
        case .untrimmedName:
            return LocalizedString("The profile name starts or ends with a space", comment: "Therapy profile error: untrimmed name")
        case .nameTooLong:
            return String(format: LocalizedString("The profile name is longer than %1$d characters", comment: "Therapy profile error: name too long (1: maximum length)"), TherapyProfileValidator.maximumNameLength)
        case .invalidNameCharacter(let character):
            return String(format: LocalizedString("The profile name cannot contain or start with '%1$@'", comment: "Therapy profile error: invalid character (1: character)"), character)
        case .reservedName:
            return String(format: LocalizedString("The name %1$@ is reserved", comment: "Therapy profile error: reserved name (1: Default)"), TherapyProfile.defaultName)
        case .duplicateName(let name):
            return String(format: LocalizedString("A profile named %1$@ already exists", comment: "Therapy profile error: duplicate name (1: name)"), name)
        case .tooManyProfiles:
            return String(format: LocalizedString("There can be at most %1$d profiles. Delete a profile before creating another.", comment: "Therapy profile error: profile limit reached (1: maximum number of profiles)"), TherapyProfileValidator.maximumProfileCount)
        case .notFound(let name):
            return String(format: LocalizedString("No profile named %1$@", comment: "Therapy profile error: not found (1: name)"), name)
        case .cannotDeleteActive:
            return LocalizedString("The active profile cannot be deleted", comment: "Therapy profile error: delete active")
        case .cannotDeleteDefault:
            return String(format: LocalizedString("The %1$@ profile cannot be deleted", comment: "Therapy profile error: delete Default (1: Default)"), TherapyProfile.defaultName)
        case .cannotRenameDefault:
            return String(format: LocalizedString("The %1$@ profile cannot be renamed", comment: "Therapy profile error: rename Default (1: Default)"), TherapyProfile.defaultName)
        case .conflict:
            return LocalizedString("The profile changed on the phone after it was uploaded. Review it again and resend.", comment: "Therapy profile error: fingerprint mismatch")
        case .noPump:
            return LocalizedString("No pump is configured, so the basal rates cannot be checked", comment: "Therapy profile error: no pump")
        case .maximumBasalRateNotSet:
            return LocalizedString("Maximum basal rate is not set, so the basal rates cannot be checked", comment: "Therapy profile error: no max basal")
        case .operationInProgress:
            return LocalizedString("Another profile change is in progress", comment: "Therapy profile error: concurrent change")
        case .pumpSyncFailed(let reason):
            return String(format: LocalizedString("The pump did not accept the basal rates: %1$@", comment: "Therapy profile error: the pump refused the basal schedule (1: pump error)"), reason)
        case .pumpSuspended:
            return LocalizedString("Insulin delivery is suspended. Resume delivery before changing the basal rates.", comment: "Therapy profile error: the pump is suspended")
        case .activeProfileChangedWhileEditing(let name):
            return String(format: LocalizedString("The active profile changed to %1$@ while these settings were open, so the change was not saved. Open the settings again to edit %1$@.", comment: "Therapy profile error: active profile changed during an edit (1: active profile name)"), name)
        case .settingsChangedWhileEditing:
            return LocalizedString("These settings changed on the phone while they were open, for example by a remote command, so the change was not saved. Open the settings again to see the current values.", comment: "Therapy profile error: settings changed during an edit")
        case .invalidSchedule(let reason):
            return reason
        case .valueOutOfRange(let reason):
            return reason
        case .unsupportedBasalRate(let rate):
            return String(format: LocalizedString("The pump does not support a basal rate of %1$@ U/hr", comment: "Therapy profile error: unsupported basal rate (1: rate)"), rate.formattedForProfileError)
        case .basalRateAboveMaximum(let rate):
            return String(format: LocalizedString("The basal rate %1$@ U/hr is above the maximum basal rate", comment: "Therapy profile error: basal above max (1: rate)"), rate.formattedForProfileError)
        case .correctionRangeBelowSuspendThreshold:
            return LocalizedString("The correction range is below the glucose safety limit", comment: "Therapy profile error: correction range below suspend threshold")
        }
    }
}

private extension Double {
    var formattedForProfileError: String {
        String(format: "%.3f", self)
    }
}

/// Operations on a list of stored profiles. The stored list is empty until the first profile other than
/// Default is created; Default then holds the live schedules.
public enum TherapyProfiles {

    /// The active profile's name, Default when `activeProfileName` is nil.
    public static func activeName(_ activeProfileName: String?) -> String {
        activeProfileName ?? TherapyProfile.defaultName
    }

    /// The stored profiles with Default first, made from the live schedules when it is not stored.
    public static func resolved(_ stored: [TherapyProfile], live: TherapyProfile?) -> [TherapyProfile] {
        var profiles = stored
        if !profiles.contains(where: \.isDefault), let live {
            var defaultProfile = live
            defaultProfile.name = TherapyProfile.defaultName
            profiles.insert(defaultProfile, at: 0)
        }
        if let index = profiles.firstIndex(where: \.isDefault), index != 0 {
            profiles.insert(profiles.remove(at: index), at: 0)
        }
        return profiles
    }

    /// The stored profiles after the live schedules are written to the active profile.
    public static func synchronizingActive(_ stored: [TherapyProfile], activeProfileName: String?, live: TherapyProfile?) -> [TherapyProfile] {
        guard !stored.isEmpty, let live else {
            return stored
        }
        var profiles = resolved(stored, live: activeName(activeProfileName) == TherapyProfile.defaultName ? live : nil)
        let active = activeName(activeProfileName)
        if let index = profiles.firstIndex(where: { $0.name == active }) {
            var updated = live
            updated.name = active
            profiles[index] = updated
        }
        return profiles
    }

    /// Creates (`originalName` nil) or updates `profile`; a different `profile.name` renames it.
    /// Returns the new stored list and the new active name.
    public static func saving(_ profile: TherapyProfile,
                              originalName: String?,
                              in stored: [TherapyProfile],
                              activeProfileName: String?,
                              live: TherapyProfile?) throws -> (profiles: [TherapyProfile], activeProfileName: String?) {
        var profiles = resolved(stored, live: activeName(activeProfileName) == TherapyProfile.defaultName ? live : nil)
        var activeProfileName = activeProfileName
        let existingNames = profiles.map(\.name)

        if let originalName {
            guard let index = profiles.firstIndex(where: { $0.name == originalName }) else {
                throw TherapyProfileError.notFound(originalName)
            }
            if profile.name != originalName {
                guard originalName != TherapyProfile.defaultName else {
                    throw TherapyProfileError.cannotRenameDefault
                }
                try TherapyProfileValidator.validateName(profile.name, isDefault: false, existingNames: existingNames.filter { $0 != originalName })
                if activeName(activeProfileName) == originalName {
                    activeProfileName = profile.name
                }
            }
            profiles[index] = profile
        } else {
            guard profiles.count < TherapyProfileValidator.maximumProfileCount else {
                throw TherapyProfileError.tooManyProfiles
            }
            try TherapyProfileValidator.validateName(profile.name, isDefault: false, existingNames: existingNames)
            profiles.append(profile)
        }
        return (profiles, activeProfileName)
    }

    /// The stored list without the profile named `name`.
    public static func deleting(_ name: String, in stored: [TherapyProfile], activeProfileName: String?, live: TherapyProfile?) throws -> [TherapyProfile] {
        guard name != TherapyProfile.defaultName else {
            throw TherapyProfileError.cannotDeleteDefault
        }
        guard name != activeName(activeProfileName) else {
            throw TherapyProfileError.cannotDeleteActive
        }
        var profiles = resolved(stored, live: activeName(activeProfileName) == TherapyProfile.defaultName ? live : nil)
        guard let index = profiles.firstIndex(where: { $0.name == name }) else {
            throw TherapyProfileError.notFound(name)
        }
        profiles.remove(at: index)
        return profiles
    }

    /// The stored list in the order of `names`, Default first. Names not in the list keep their relative order at the end.
    public static func reordering(_ stored: [TherapyProfile], names: [String], live: TherapyProfile?, activeProfileName: String?) -> [TherapyProfile] {
        let profiles = resolved(stored, live: activeName(activeProfileName) == TherapyProfile.defaultName ? live : nil)
        let ordered = names.compactMap { name in profiles.first(where: { $0.name == name }) }
        let rest = profiles.filter { profile in !names.contains(profile.name) }
        return resolved(ordered + rest, live: nil)
    }
}

// MARK: - Host operations

/// Profile operations the host app performs. Every operation validates first; switching and saving the
/// active profile write the basal schedule to the pump before any setting changes. With an `expectedFingerprint`,
/// the operation throws `TherapyProfileError.conflict` unless the profile as stored on the phone (for a save, the
/// original) matches it right before the change.
@MainActor
public protocol TherapyProfileDelegate: AnyObject {
    /// All profiles, Default first.
    var therapyProfiles: [TherapyProfile] { get }

    var activeTherapyProfileName: String { get }

    func activateTherapyProfile(named name: String, expectedFingerprint: String?, trigger: TherapyProfileSwitchTrigger) async throws

    /// Creates the profile when `originalName` is nil, else updates (and with a new name, renames) that profile.
    /// Scheduled switches follow a rename.
    func saveTherapyProfile(_ profile: TherapyProfile, originalName: String?, expectedFingerprint: String?) async throws

    /// Deletes the profile and the scheduled switches to it.
    func deleteTherapyProfile(named name: String, expectedFingerprint: String?) async throws

    func reorderTherapyProfiles(names: [String])

    var scheduledProfileSwitches: [ScheduledProfileSwitch] { get }

    /// Replaces the scheduled switches. With an `expectedFingerprint`, throws `ScheduledProfileSwitchError.conflict`
    /// unless the current list has it. Only starts after the save run.
    func saveScheduledProfileSwitches(_ entries: [ScheduledProfileSwitch], expectedFingerprint: String?) async throws
}

public extension TherapyProfileDelegate {
    func activateTherapyProfile(named name: String) async throws {
        try await activateTherapyProfile(named: name, expectedFingerprint: nil, trigger: .local)
    }

    func saveTherapyProfile(_ profile: TherapyProfile, originalName: String?) async throws {
        try await saveTherapyProfile(profile, originalName: originalName, expectedFingerprint: nil)
    }

    func deleteTherapyProfile(named name: String) async throws {
        try await deleteTherapyProfile(named: name, expectedFingerprint: nil)
    }

    func therapyProfile(named name: String) -> TherapyProfile? {
        therapyProfiles.first { $0.name == name }
    }
}
