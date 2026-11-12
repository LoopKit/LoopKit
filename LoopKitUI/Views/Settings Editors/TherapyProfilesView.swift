//
//  TherapyProfilesView.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftUI

public struct TherapyProfilesView: View {
    @ObservedObject public var viewModel: TherapyProfilesViewModel
    @Environment(\.dismissAction) var dismissAction
    @Environment(\.appName) private var appName
    @State private var isAddingNewProfile = false
    @State private var showingInfo = false
    @State private var scheduledSwitchError: String?

    public init(viewModel: TherapyProfilesViewModel) {
        self.viewModel = viewModel
    }

    private var dismissButton: some View {
        Button(action: dismissAction) {
            Text(LocalizedString("Done", comment: "Text for dismiss button"))
                .bold()
        }
    }

    public var body: some View {
        ZStack {
            NavigationStack {
                List {
                    Section(footer: Text(String(format: LocalizedString("%1$@ doses with the profile marked with a checkmark. Tap a profile to review, edit, activate, rename or delete it.", comment: "Profiles list footer (1: app name)"), appName))) {
                        ForEach(viewModel.profiles, id: \.name) { profile in
                            NavigationLink(destination: TherapyProfileView(viewModel: viewModel, profileName: profile.name)) {
                                HStack {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .opacity(viewModel.isActive(profile) ? 1 : 0)
                                    Text(profile.name)
                                    Spacer()
                                    if viewModel.isActive(profile) {
                                        Text(LocalizedString("Active", comment: "Label of the active profile in the profile list"))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .moveDisabled(profile.isDefault)
                            .accessibilityIdentifier("profile_\(profile.name)")
                        }
                        .onMove(perform: viewModel.moveProfiles)
                    }
                    scheduledSwitchesSection
                }
                .insetGroupedListStyle()
                .navigationBarItems(
                    leading: HStack {
                        Button(action: { withAnimation { isAddingNewProfile = true } }) {
                            Image(systemName: "plus")
                        }
                        .accessibilityIdentifier("button_AddProfile")

                        Button(action: { showingInfo = true }) {
                            Image(systemName: "info.circle")
                        }
                    },
                    trailing: dismissButton
                )
                .navigationTitle(Text(LocalizedString("Profiles", comment: "Title on TherapyProfilesView")))
            }
            .onAppear { viewModel.reload() }
            .alert(LocalizedString("Scheduled Switches Not Saved", comment: "Title of the alert when a change of the scheduled switches fails"),
                   isPresented: Binding(get: { scheduledSwitchError != nil }, set: { if !$0 { scheduledSwitchError = nil } }),
                   actions: {},
                   message: { Text(scheduledSwitchError ?? "") })
            .alert(isPresented: $showingInfo) {
                Alert(title: Text(LocalizedString("Profiles", comment: "Title on TherapyProfilesView")),
                      message: Text(String(format: LocalizedString("A profile holds a correction range, carb ratios, basal rates and insulin sensitivities. %1$@ doses with the active profile, marked with a checkmark.\n\nUse ‘+’ to create a profile from the active profile's settings.\n\nTap a profile to review it. There you can edit its settings and activate, rename or delete it. Editing the active profile changes the settings %1$@ doses with right away.\n\nTo change the order, press and hold a profile and drag it.", comment: "Profiles information (1: app name)"), appName)
                                   + "\n\n"
                                   + String(format: LocalizedString("Scheduled switches make a profile active at a time each week, for example Weekend on Saturday 07:00 and Default on Monday 06:00. A profile stays active until the next scheduled start, also after a switch you make yourself. %1$@ switches on its next loop after the time, and tells you when it switched or when it could not.", comment: "Profiles information about scheduled switches (1: app name)"), appName)),
                      dismissButton: .default(Text(LocalizedString("Got it!", comment: "Dismiss button of the profiles information"))))
            }

            if isAddingNewProfile {
                DarkenedOverlay()

                NewTherapyProfileEditor(isPresented: $isAddingNewProfile, viewModel: viewModel)
                    .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity).animation(.default))
            }
        }
    }

    private var scheduledSwitchesSection: some View {
        Section(header: Text(LocalizedString("Scheduled Switches", comment: "Header of the scheduled profile switches")),
                footer: Text(scheduledSwitchesFooter)) {
            ForEach(viewModel.scheduledSwitchesAsWeek) { entry in
                NavigationLink(destination: ScheduledProfileSwitchEditor(viewModel: viewModel, entry: entry)) {
                    scheduledSwitchRow(entry)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        changeScheduledSwitches { try await viewModel.deleteScheduledSwitch(entry) }
                    } label: {
                        Text(LocalizedString("Delete", comment: "Swipe action to delete a scheduled switch"))
                    }
                    Button {
                        changeScheduledSwitches { try await viewModel.setScheduledSwitch(entry, paused: !entry.paused) }
                    } label: {
                        Text(entry.paused ? LocalizedString("Resume", comment: "Swipe action to resume a paused scheduled switch") : LocalizedString("Pause", comment: "Swipe action to pause a scheduled switch"))
                    }
                    .tint(.orange)
                }
                .accessibilityIdentifier("scheduledSwitch_\(entry.profileName)_\(entry.weekday)_\(Int(entry.time))")
            }
            if viewModel.canAddScheduledSwitch {
                NavigationLink(destination: ScheduledProfileSwitchEditor(viewModel: viewModel)) {
                    Text(LocalizedString("Add Scheduled Switch", comment: "Button to add a scheduled profile switch"))
                        .foregroundColor(.accentColor)
                }
                .accessibilityIdentifier("button_AddScheduledSwitch")
            }
        }
    }

    private func scheduledSwitchRow(_ entry: ScheduledProfileSwitch) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(format: LocalizedString("%1$@ %2$@ · %3$@ starts", comment: "Scheduled switch row (1: short weekday, 2: time, 3: profile name)"),
                        ScheduledProfileSwitches.weekdayName(entry.weekday, short: true), ScheduledProfileSwitches.localizedTime(entry.time), entry.profileName))
            Group {
                if entry.paused {
                    Text(LocalizedString("Paused", comment: "Span line of a paused scheduled switch"))
                } else if let end = viewModel.scheduledSwitchSpanEnd(of: entry) {
                    Text(String(format: LocalizedString("until %1$@", comment: "Span line of a scheduled switch: until the next start (1: short weekday and time)"), end))
                } else {
                    Text(LocalizedString("every week", comment: "Span line of the only scheduled switch that is not paused"))
                }
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .opacity(entry.paused ? 0.5 : 1)
    }

    private var scheduledSwitchesFooter: String {
        guard !viewModel.scheduledSwitches.isEmpty else {
            return String(format: LocalizedString("No scheduled switches. %1$@ keeps the active profile until you switch.", comment: "Footer of the scheduled switches when there are none (1: app name)"), appName)
        }
        guard let next = viewModel.nextScheduledSwitch() else {
            return LocalizedString("All starts are paused.", comment: "Footer of the scheduled switches when every start is paused")
        }
        var footer = String(format: LocalizedString("Next: %1$@.", comment: "Footer of the scheduled switches naming the next start (1: profile name, weekday and time)"), next.entry.localizedDescription)
        let running = viewModel.scheduledSwitches.filter { !$0.paused }
        if running.count == 1 {
            footer += " " + String(format: LocalizedString("%1$@ starts again every %2$@ after a manual switch.", comment: "Footer of the scheduled switches with one start that is not paused (1: profile name, 2: weekday and time)"), next.entry.profileName, next.entry.localizedWeekdayAndTime)
        }
        return footer
    }

    private func changeScheduledSwitches(_ change: @escaping () async throws -> Void) {
        Task {
            do {
                try await change()
            } catch {
                scheduledSwitchError = error.localizedDescription
            }
        }
    }
}
