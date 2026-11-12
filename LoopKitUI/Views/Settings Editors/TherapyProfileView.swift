//
//  TherapyProfileView.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import SwiftUI
import LoopKit

/// The screen's one alert: a confirmation or an error. SwiftUI presents a single alert per screen.
private enum ProfileAlert: Identifiable, Equatable {
    case activate
    case delete
    case error(id: UUID, text: String)

    var id: String {
        switch self {
        case .activate: return "activate"
        case .delete: return "delete"
        case let .error(id, _): return id.uuidString
        }
    }
}

struct TherapyProfileView: View {
    @EnvironmentObject private var displayGlucosePreference: DisplayGlucosePreference
    @ObservedObject var viewModel: TherapyProfilesViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.appName) private var appName
    @Environment(\.dosingStrategySelectionEnabled) private var dosingStrategySelectionEnabled
    let profileName: String

    @StateObject private var editingDelegate: TherapyProfileEditingDelegate
    @State private var therapySettingsViewModel: TherapySettingsViewModel
    @State private var alert: ProfileAlert?
    @State private var isRenamingProfile = false
    @State private var isWorking = false

    init(viewModel: TherapyProfilesViewModel, profileName: String) {
        self.viewModel = viewModel
        self.profileName = profileName
        let editingDelegate = TherapyProfileEditingDelegate(viewModel: viewModel, profileName: profileName)
        _editingDelegate = StateObject(wrappedValue: editingDelegate)
        _therapySettingsViewModel = State(initialValue: viewModel.therapySettingsViewModel(forProfileNamed: profileName, editingDelegate: editingDelegate))
    }

    private var profile: TherapyProfile? {
        viewModel.profile(named: profileName)
    }

    private var isActive: Bool {
        profileName == viewModel.activeProfileName
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(explanation)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding([.leading, .trailing])
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("text_ProfileExplanation")

                    if profile != nil {
                        profileCardStack
                    }

                    if !isActive {
                        actionButton(LocalizedString("Activate", comment: "Button to activate a therapy profile"), style: .primary, identifier: "button_ActivateProfile") {
                            alert = .activate
                        }
                    }
                    if profileName != TherapyProfile.defaultName {
                        actionButton(LocalizedString("Rename", comment: "Button to rename a therapy profile"), style: .secondary, identifier: "button_RenameProfile") {
                            isRenamingProfile = true
                        }
                    }
                    if profileName != TherapyProfile.defaultName && !isActive {
                        actionButton(LocalizedString("Delete", comment: "Button to delete a therapy profile"), style: .destructive, identifier: "button_DeleteProfile") {
                            alert = .delete
                        }
                    }
                }
            }
            .disabled(isWorking)
            .navigationBarHidden(false)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Text(profileName))

            if isRenamingProfile {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        isRenamingProfile = false
                    }

                RenameTherapyProfileEditor(
                    isPresented: $isRenamingProfile,
                    originalName: profileName,
                    viewModel: viewModel,
                    didRename: { presentationMode.wrappedValue.dismiss() }
                )
                .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity).animation(.default))
                .offset(y: -22)
            }

            if isWorking {
                SwiftUI.ProgressView()
            }
        }
        .alert(item: $alert) { alert in
            switch alert {
            case .activate:
                return Alert(
                    title: Text(LocalizedString("Activate Profile", comment: "Title of the activate profile confirmation")),
                    message: Text(String(format: LocalizedString("%1$@ writes the basal rates of %2$@ to the pump and doses with its settings right away.", comment: "Activate profile confirmation (1: app name, 2: profile name)"), appName, profileName) + activationScheduleText),
                    primaryButton: .default(Text(LocalizedString("Activate", comment: "Button to activate a therapy profile")), action: activate),
                    secondaryButton: .cancel()
                )
            case .delete:
                return Alert(
                    title: Text(LocalizedString("Delete Profile", comment: "Title of the delete profile confirmation")),
                    message: Text(String(format: LocalizedString("Delete the profile %1$@? This cannot be undone.", comment: "Delete profile confirmation (1: profile name)"), profileName) + deletionScheduleText),
                    primaryButton: .destructive(Text(LocalizedString("Delete", comment: "Button to delete a therapy profile")), action: delete),
                    secondaryButton: .cancel()
                )
            case let .error(_, text):
                return Alert(
                    title: Text(LocalizedString("Profile Not Changed", comment: "Title of a profile error")),
                    message: Text(text),
                    dismissButton: .default(Text(LocalizedString("OK", comment: "Button to dismiss a profile error")))
                )
            }
        }
        .onAppear {
            // Runs again when an editor closes, so the editors start from the stored values.
            viewModel.reload()
            if let saveError = therapySettingsViewModel.saveError {
                therapySettingsViewModel.saveError = nil
                editingDelegate.report(saveError.localizedDescription)
            }
            therapySettingsViewModel = viewModel.therapySettingsViewModel(forProfileNamed: profileName, editingDelegate: editingDelegate)
            editingDelegate.isScreenVisible = true
        }
        .onDisappear {
            editingDelegate.isScreenVisible = false
        }
        .onChange(of: alert) {
            editingDelegate.isShowingAlert = alert != nil
        }
        .onReceive(editingDelegate.$errorToPresent) { message in
            guard let message else { return }
            editingDelegate.isShowingAlert = true
            alert = .error(id: UUID(), text: message)
            editingDelegate.errorWasPresented()
        }
    }

    private var explanation: String {
        if isActive {
            return String(format: LocalizedString("%1$@ is the active profile. Editing a setting here changes the settings %2$@ doses with right away, and basal rates are written to the pump.", comment: "Explanation for the active profile (1: profile name, 2: app name)"), profileName, appName)
        } else {
            return String(format: LocalizedString("Editing a setting here changes only %1$@. %2$@ keeps dosing with %3$@ until you activate %1$@.", comment: "Explanation for a profile that is not active (1: profile name, 2: app name, 3: active profile name)"), profileName, appName, viewModel.activeProfileName)
        }
    }

    private func actionButton(_ title: String, style: ActionButtonStyle.ButtonType, identifier: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(ActionButtonStyle(style))
            .padding(.horizontal)
            .accessibilityIdentifier(identifier)
    }

    private func activate() {
        perform { try await viewModel.activateProfile(named: profileName) }
    }

    /// " It stays active until Weekend starts Saturday 13:00." when a start is scheduled.
    private var activationScheduleText: String {
        guard let next = viewModel.nextScheduledSwitch() else {
            return ""
        }
        return " " + String(format: LocalizedString("It stays active until %1$@.", comment: "Activate profile confirmation: the next scheduled start (1: profile name, weekday and time)"), next.entry.localizedDescription)
    }

    /// The scheduled switches the deletion removes, and what that does to the week.
    private var deletionScheduleText: String {
        let count = viewModel.scheduledSwitchCount(forProfileNamed: profileName)
        guard count > 0 else {
            return ""
        }
        let removed = count == 1
            ? String(format: LocalizedString("%1$@ is used by 1 scheduled switch, which will be removed.", comment: "Delete profile confirmation: one scheduled switch removed (1: profile name)"), profileName)
            : String(format: LocalizedString("%1$@ is used by %2$d scheduled switches, which will be removed.", comment: "Delete profile confirmation: scheduled switches removed (1: profile name, 2: number of scheduled switches)"), profileName, count)
        return "\n\n" + removed + " " + LocalizedString("At those times the profile active before stays active until the next scheduled start.", comment: "Delete profile confirmation: what removing scheduled switches does to the week")
    }

    private func delete() {
        perform { try await viewModel.deleteProfile(named: profileName) }
    }

    /// Runs a confirmed change after its confirmation alert is gone, then closes the screen or shows the error.
    private func perform(_ change: @escaping () async throws -> Void) {
        isWorking = true
        Task {
            do {
                try await change()
                isWorking = false
                presentationMode.wrappedValue.dismiss()
            } catch {
                isWorking = false
                editingDelegate.report(error.localizedDescription)
            }
        }
    }

    private var profileCardStack: CardStack {
        CardStack(cards: [correctionRangeSection, carbRatioSection, basalRatesSection, insulinSensitivitiesSection])
    }

    private var correctionRangeSection: Card {
        card(for: .glucoseTargetRange) {
            if let items = profile?.glucoseTargetRangeSchedule.schedule(for: glucoseUnit)?.items {
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }
                    ScheduleRangeItem(time: items[index].startTime,
                                      range: items[index].value,
                                      unit: glucoseUnit,
                                      guardrail: .correctionRange)
                }
            }
        }
    }

    private var carbRatioSection: Card {
        card(for: .carbRatio) {
            if let items = profile?.carbRatioSchedule.items {
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }
                    ScheduleValueItem(time: items[index].startTime,
                                      value: items[index].value,
                                      unit: .gramsPerUnit,
                                      guardrail: .carbRatio)
                }
            }
        }
    }

    private var basalRatesSection: Card {
        card(for: .basalRate) {
            if let schedule = profile?.basalRateSchedule, let supportedBasalRates = viewModel.pumpSupportedIncrements()?.basalRates {
                let items = schedule.items
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }
                    ScheduleValueItem(time: items[index].startTime,
                                      value: items[index].value,
                                      unit: .internationalUnitsPerHour,
                                      guardrail: .basalRate(supportedBasalRates: supportedBasalRates))
                }
                HStack {
                    Text(LocalizedString("Total", comment: "The text indicating Total for Daily Schedule Basal"))
                        .bold()
                        .foregroundColor(.primary)
                    Spacer()
                    Text((QuantityFormatter(for: .internationalUnitsPerHour).numberFormatter.string(from: NSNumber(value: schedule.total())) ?? "") + " ")
                        .foregroundColor(.primary) +
                    Text(LocalizedString("U/day", comment: "The text indicating U/day for Daily Schedule Basal"))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var insulinSensitivitiesSection: Card {
        card(for: .insulinSensitivity) {
            if let items = profile?.insulinSensitivitySchedule.schedule(for: glucoseUnit)?.items {
                SectionDivider()
                ForEach(items.indices, id: \.self) { index in
                    if index > 0 {
                        SettingsDivider()
                    }
                    ScheduleValueItem(time: items[index].startTime,
                                      value: items[index].value,
                                      unit: sensitivityUnit,
                                      guardrail: .insulinSensitivity)
                }
            }
        }
    }
}

// MARK: Utilities
extension TherapyProfileView {

    private var glucoseUnit: LoopUnit {
        displayGlucosePreference.unit
    }

    private var sensitivityUnit: LoopUnit {
        glucoseUnit == .millimolesPerLiter ? .millimolesPerLiterPerInternationalUnit : .milligramsPerDeciliterPerInternationalUnit
    }

    private func card<Content>(for therapySetting: TherapySetting, @ViewBuilder content: @escaping () -> Content) -> Card where Content: View {
        Card {
            SectionWithTapToEdit(
                // The basal editor needs the pump's supported rates.
                isEnabled: therapySetting != .basalRate || viewModel.pumpSupportedIncrements() != nil,
                title: therapySetting.title,
                descriptiveText: therapySetting.descriptiveText(appName: appName, dosingStrategySelectionEnabled: dosingStrategySelectionEnabled),
                destination: { goBack in
                    PoppingEditor { pop in
                        let close = {
                            pop()
                            goBack()
                        }
                        return editor(for: therapySetting, dismiss: close)
                            .environment(\.dismissAction, close)
                    }
                },
                content: content
            )
        }
    }

    @ViewBuilder
    private func editor(for therapySetting: TherapySetting, dismiss: @escaping () -> Void) -> some View {
        switch therapySetting {
        case .glucoseTargetRange:
            CorrectionRangeScheduleEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: dismiss)
        case .carbRatio:
            CarbRatioScheduleEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: dismiss)
        case .basalRate:
            BasalRateScheduleEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: dismiss)
        case .insulinSensitivity:
            InsulinSensitivityScheduleEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: dismiss)
        default:
            EmptyView()
        }
    }
}

fileprivate struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.trailing, -16)
    }
}

fileprivate struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.trailing, -8)
    }
}

/// Hands `content` a closure that pops it from the navigation stack. The profile screens live in a `NavigationStack`,
/// where the editor's `NavigationLink(isActive:)` does not pop when it is set back to false.
private struct PoppingEditor<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    let content: (@escaping () -> Void) -> Content

    var body: some View {
        content { dismiss() }
    }
}
