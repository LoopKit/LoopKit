//
//  ScheduledProfileSwitchEditor.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

/// Adds or edits one weekly profile start: a profile, a weekday and a time.
struct ScheduledProfileSwitchEditor: View {
    @ObservedObject var viewModel: TherapyProfilesViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appName) private var appName

    private let isNew: Bool
    @State private var entry: ScheduledProfileSwitch
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(viewModel: TherapyProfilesViewModel, entry: ScheduledProfileSwitch? = nil) {
        self.viewModel = viewModel
        self.isNew = entry == nil
        self._entry = State(initialValue: entry ?? ScheduledProfileSwitch(profileName: viewModel.profiles.first?.name ?? TherapyProfile.defaultName,
                                                                          weekday: 2,
                                                                          time: .hours(7)))
    }

    /// Weekdays from Monday, as `Calendar` numbers them.
    private let weekdays = [2, 3, 4, 5, 6, 7, 1]

    private var time: Binding<Date> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return Binding(
            get: { Date(timeIntervalSinceReferenceDate: entry.time) },
            set: { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                entry.time = TimeInterval((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60)
            })
    }

    private var summary: String {
        String(format: LocalizedString("%1$@ starts every %2$@ at %3$@ and stays active until the next scheduled start.", comment: "Scheduled switch editor footer (1: profile name, 2: weekday, 3: time)"),
               entry.profileName, ScheduledProfileSwitches.weekdayName(entry.weekday), ScheduledProfileSwitches.localizedTime(entry.time))
    }

    var body: some View {
        List {
            Section(footer: Text(summary)) {
                Picker(LocalizedString("Profile", comment: "Scheduled switch editor: profile picker label"), selection: $entry.profileName) {
                    ForEach(viewModel.profiles, id: \.name) { profile in
                        Text(profile.name).tag(profile.name)
                    }
                }
                .accessibilityIdentifier("picker_ScheduledSwitchProfile")
                Picker(LocalizedString("Day", comment: "Scheduled switch editor: weekday picker label"), selection: $entry.weekday) {
                    ForEach(weekdays, id: \.self) { weekday in
                        Text(ScheduledProfileSwitches.weekdayName(weekday)).tag(weekday)
                    }
                }
                .accessibilityIdentifier("picker_ScheduledSwitchWeekday")
                DatePicker(LocalizedString("Time", comment: "Scheduled switch editor: time picker label"), selection: time, displayedComponents: .hourAndMinute)
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                    .accessibilityIdentifier("picker_ScheduledSwitchTime")
            }
            Section(footer: Text(String(format: LocalizedString("A paused start does not run until you resume it. Nothing is switched when you resume; the start runs again at its next time. %1$@ does not remind you of a paused start.", comment: "Scheduled switch editor: paused footer (1: app name)"), appName))) {
                Toggle(LocalizedString("Paused", comment: "Scheduled switch editor: paused toggle label"), isOn: $entry.paused)
                    .accessibilityIdentifier("toggle_ScheduledSwitchPaused")
            }
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .accessibilityIdentifier("text_ScheduledSwitchError")
                }
            }
        }
        .insetGroupedListStyle()
        .navigationTitle(isNew ? LocalizedString("Add Scheduled Switch", comment: "Title of the scheduled switch editor for a new start") : LocalizedString("Scheduled Switch", comment: "Title of the scheduled switch editor"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizedString("Save", comment: "Button to save a scheduled switch"), action: save)
                    .disabled(isSaving)
                    .accessibilityIdentifier("button_SaveScheduledSwitch")
            }
        }
        .onChange(of: entry) {
            errorMessage = nil
        }
    }

    private func save() {
        do {
            try viewModel.validateScheduledSwitch(entry)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        isSaving = true
        Task {
            do {
                try await viewModel.saveScheduledSwitch(entry)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
