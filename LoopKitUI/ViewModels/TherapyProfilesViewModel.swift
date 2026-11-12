//
//  TherapyProfilesViewModel.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftUI

/// The therapy profiles shown in the Profiles screen. Changes go through the host's `TherapyProfileDelegate`,
/// which validates them and keeps the live settings equal to the active profile.
@MainActor
public final class TherapyProfilesViewModel: ObservableObject {

    @Published private(set) var profiles: [TherapyProfile] = []
    @Published private(set) var activeProfileName: String = TherapyProfile.defaultName
    @Published private(set) var scheduledSwitches: [ScheduledProfileSwitch] = []

    private weak var profileDelegate: TherapyProfileDelegate?
    /// Saves edits of the active profile, the same way as the Therapy Settings screen.
    private weak var therapySettingsDelegate: TherapySettingsViewModelDelegate?
    private let liveTherapySettings: () -> TherapySettings

    public init(profileDelegate: TherapyProfileDelegate?,
                therapySettingsDelegate: TherapySettingsViewModelDelegate?,
                therapySettings: @escaping () -> TherapySettings) {
        self.profileDelegate = profileDelegate
        self.therapySettingsDelegate = therapySettingsDelegate
        self.liveTherapySettings = therapySettings
        reload()
    }

    func reload() {
        profiles = profileDelegate?.therapyProfiles ?? []
        activeProfileName = profileDelegate?.activeTherapyProfileName ?? TherapyProfile.defaultName
        scheduledSwitches = profileDelegate?.scheduledProfileSwitches ?? []
    }

    var therapySettings: TherapySettings {
        liveTherapySettings()
    }

    func profile(named name: String) -> TherapyProfile? {
        profiles.first { $0.name == name }
    }

    func isActive(_ profile: TherapyProfile) -> Bool {
        profile.name == activeProfileName
    }

    func pumpSupportedIncrements() -> PumpSupportedIncrements? {
        therapySettingsDelegate?.pumpSupportedIncrements()
    }

    /// Creates a profile named `name` with the values of the active profile.
    func createProfile(named name: String) async throws {
        guard var profile = profile(named: activeProfileName) else {
            throw TherapyProfileError.notFound(activeProfileName)
        }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { reload() }
        try await delegate().saveTherapyProfile(profile, originalName: nil)
    }

    func renameProfile(_ originalName: String, to newName: String) async throws {
        guard var profile = profile(named: originalName) else {
            throw TherapyProfileError.notFound(originalName)
        }
        profile.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { reload() }
        try await delegate().saveTherapyProfile(profile, originalName: originalName)
    }

    func activateProfile(named name: String) async throws {
        defer { reload() }
        try await delegate().activateTherapyProfile(named: name)
    }

    func deleteProfile(named name: String) async throws {
        defer { reload() }
        try await delegate().deleteTherapyProfile(named: name)
    }

    func moveProfiles(from source: IndexSet, to destination: Int) {
        var names = profiles.map(\.name)
        names.move(fromOffsets: source, toOffset: destination)
        profileDelegate?.reorderTherapyProfiles(names: names)
        reload()
    }

    /// Throws when the profile named `name` is active or holds other values than `base`, the settings an editor
    /// opened with, so a stale edit is never saved.
    func validateEdit(ofProfileNamed name: String, from base: TherapySettings) throws {
        reload()
        let delegate = try delegate()
        try Self.validateEdit(ofProfileNamed: name, from: base, delegate: delegate)
    }

    /// Returns the profile `base` describes.
    @discardableResult
    private static func validateEdit(ofProfileNamed name: String, from base: TherapySettings, delegate: TherapyProfileDelegate) throws -> TherapyProfile {
        guard delegate.activeTherapyProfileName != name else {
            throw TherapyProfileError.activeProfileChangedWhileEditing(name)
        }
        guard let stored = delegate.therapyProfile(named: name) else {
            throw TherapyProfileError.notFound(name)
        }
        guard let baseProfile = TherapyProfile(name: name,
                                               glucoseTargetRangeSchedule: base.glucoseTargetRangeSchedule,
                                               carbRatioSchedule: base.carbRatioSchedule,
                                               basalRateSchedule: base.basalRateSchedule,
                                               insulinSensitivitySchedule: base.insulinSensitivitySchedule),
              stored.hasSameValues(as: baseProfile)
        else {
            throw TherapyProfileError.settingsChangedWhileEditing
        }
        return baseProfile
    }

    /// Saves the four schedules in `settings` to the profile named `name`, which must still hold the values of `base`
    /// and not be active.
    func updateProfile(named name: String, editedFrom base: TherapySettings, to settings: TherapySettings) async throws {
        let delegate = try delegate()
        guard let profile = TherapyProfile(name: name,
                                           glucoseTargetRangeSchedule: settings.glucoseTargetRangeSchedule,
                                           carbRatioSchedule: settings.carbRatioSchedule,
                                           basalRateSchedule: settings.basalRateSchedule,
                                           insulinSensitivitySchedule: settings.insulinSensitivitySchedule)
        else {
            throw TherapyProfileError.notFound(name)
        }
        defer { reload() }
        let baseProfile = try Self.validateEdit(ofProfileNamed: name, from: base, delegate: delegate)
        guard let baseFingerprint = baseProfile.fingerprint(unit: baseProfile.glucoseTargetRangeSchedule.unit) else {
            throw TherapyProfileError.settingsChangedWhileEditing
        }
        try await delegate.saveTherapyProfile(profile, originalName: name, expectedFingerprint: baseFingerprint)
    }

    /// The live settings with the schedules of `profile`, for editing the profile with the therapy settings editors.
    func therapySettings(applying profile: TherapyProfile) -> TherapySettings {
        var settings = therapySettings
        let unit = settings.glucoseTargetRangeSchedule?.unit ?? profile.glucoseTargetRangeSchedule.unit
        let converted = profile.withGlucoseUnit(unit)
        settings.glucoseTargetRangeSchedule = converted.glucoseTargetRangeSchedule
        settings.carbRatioSchedule = converted.carbRatioSchedule
        settings.basalRateSchedule = converted.basalRateSchedule
        settings.insulinSensitivitySchedule = converted.insulinSensitivitySchedule
        return settings
    }

    /// The settings view model for editing the profile named `name`. The active profile is edited like the Therapy
    /// Settings screen, so basal rates go to the pump and the change takes effect at once.
    func therapySettingsViewModel(forProfileNamed name: String, editingDelegate: TherapyProfileEditingDelegate) -> TherapySettingsViewModel {
        if name == activeProfileName {
            return TherapySettingsViewModel(therapySettings: therapySettings, delegate: therapySettingsDelegate)
        }
        let settings = profile(named: name).map { therapySettings(applying: $0) } ?? therapySettings
        return TherapySettingsViewModel(therapySettings: settings, delegate: editingDelegate)
    }

    // MARK: Scheduled switches

    /// The time zone of the therapy schedules, which the scheduled switch times are in.
    var scheduleTimeZone: TimeZone {
        therapySettings.basalRateSchedule?.timeZone ?? .current
    }

    /// The scheduled switches as a week from Monday.
    var scheduledSwitchesAsWeek: [ScheduledProfileSwitch] {
        ScheduledProfileSwitches.sortedAsWeek(scheduledSwitches)
    }

    var canAddScheduledSwitch: Bool {
        scheduledSwitches.count < ScheduledProfileSwitches.maximumCount
    }

    func nextScheduledSwitch(after date: Date = Date()) -> ScheduledProfileSwitchOccurrence? {
        ScheduledProfileSwitches.next(in: scheduledSwitches, after: date, timeZone: scheduleTimeZone)
    }

    /// The start that ends the profile `entry` starts, or nil when no other start follows: "Sat 13:00".
    func scheduledSwitchSpanEnd(of entry: ScheduledProfileSwitch, after date: Date = Date()) -> String? {
        var running = entry
        running.paused = false
        guard let start = ScheduledProfileSwitches.next(in: [running], after: date, timeZone: scheduleTimeZone),
              let end = ScheduledProfileSwitches.next(in: scheduledSwitches.filter { $0.id != entry.id }, after: start.date, timeZone: scheduleTimeZone)
        else {
            return nil
        }
        return ScheduledProfileSwitches.weekdayName(end.entry.weekday, short: true) + " " + ScheduledProfileSwitches.localizedTime(end.entry.time)
    }

    func scheduledSwitchCount(forProfileNamed name: String) -> Int {
        scheduledSwitches.filter { $0.profileName == name }.count
    }

    /// Replaces the scheduled switches, unless they changed elsewhere since they were loaded.
    func saveScheduledSwitches(_ entries: [ScheduledProfileSwitch]) async throws {
        let expectedFingerprint = ScheduledProfileSwitches.fingerprint(scheduledSwitches)
        defer { reload() }
        try await delegate().saveScheduledProfileSwitches(entries, expectedFingerprint: expectedFingerprint)
    }

    /// Adds `entry`, or replaces the entry with its identifier.
    func saveScheduledSwitch(_ entry: ScheduledProfileSwitch) async throws {
        var entries = scheduledSwitches
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        try await saveScheduledSwitches(entries)
    }

    func deleteScheduledSwitch(_ entry: ScheduledProfileSwitch) async throws {
        try await saveScheduledSwitches(scheduledSwitches.filter { $0.id != entry.id })
    }

    func setScheduledSwitch(_ entry: ScheduledProfileSwitch, paused: Bool) async throws {
        var entry = entry
        entry.paused = paused
        try await saveScheduledSwitch(entry)
    }

    /// Throws when `entry` would break a rule of the list, so the editor can say why before saving.
    func validateScheduledSwitch(_ entry: ScheduledProfileSwitch) throws {
        var entries = scheduledSwitches.filter { $0.id != entry.id }
        entries.append(entry)
        try ScheduledProfileSwitches.validate(entries, profileNames: profiles.map(\.name))
    }

    private func delegate() throws -> TherapyProfileDelegate {
        guard let profileDelegate else {
            throw TherapyProfilesUnavailableError()
        }
        return profileDelegate
    }
}

struct TherapyProfilesUnavailableError: LocalizedError {
    var errorDescription: String? {
        LocalizedString("Profiles are not available", comment: "Therapy profile error: no profile handler")
    }
}

/// Saves edits made with the therapy settings editors to a profile that is not active. The live settings and the
/// pump are not changed. The editors call it on the main actor.
@MainActor
final class TherapyProfileEditingDelegate: ObservableObject, @preconcurrency TherapySettingsViewModelDelegate {
    private let viewModel: TherapyProfilesViewModel
    private let profileName: String
    /// The settings the last accepted edit started from.
    private var editBase: TherapySettings?
    /// An error for the profile screen to show now.
    @Published private(set) var errorToPresent: String?
    /// An error waiting until the profile screen is visible and shows no other alert, for example while an editor closes.
    private var pendingError: String?
    var isScreenVisible = false {
        didSet { presentPendingError() }
    }
    var isShowingAlert = false {
        didSet { presentPendingError() }
    }

    init(viewModel: TherapyProfilesViewModel, profileName: String) {
        self.viewModel = viewModel
        self.profileName = profileName
    }

    func syncBasalRateSchedule(items: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) {
        let timeZone = viewModel.profile(named: profileName)?.basalRateSchedule.timeZone
        guard let schedule = BasalRateSchedule(dailyItems: items, timeZone: timeZone) else {
            completion(.failure(TherapyProfileError.invalidSchedule(LocalizedString("The basal rate schedule is empty", comment: "Therapy profile error: empty basal schedule"))))
            return
        }
        completion(.success(schedule))
    }

    func syncDeliveryLimits(deliveryLimits: DeliveryLimits) async throws -> DeliveryLimits {
        deliveryLimits
    }

    /// Refuses the edit when the profile became active or changed after the editor opened.
    func validateTherapySettingsEdit(from therapySettings: TherapySettings) throws {
        try viewModel.validateEdit(ofProfileNamed: profileName, from: therapySettings)
        editBase = therapySettings
    }

    func saveCompletion(therapySettings: TherapySettings) {
        guard let editBase else {
            return
        }
        self.editBase = nil
        Task {
            do {
                try await viewModel.updateProfile(named: profileName, editedFrom: editBase, to: therapySettings)
            } catch {
                report(error.localizedDescription)
            }
        }
    }

    func report(_ message: String) {
        pendingError = message
        presentPendingError()
    }

    func errorWasPresented() {
        errorToPresent = nil
        presentPendingError()
    }

    private func presentPendingError() {
        guard isScreenVisible, !isShowingAlert, errorToPresent == nil, let pendingError else {
            return
        }
        self.pendingError = nil
        errorToPresent = pendingError
    }

    func pumpSupportedIncrements() -> PumpSupportedIncrements? {
        viewModel.pumpSupportedIncrements()
    }
}
