//
//  EditPresetView.swift
//  Loop
//
//  Created by Pete Schwamb on 12/09/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm
import LoopKit
import SwiftUI

public struct EditPresetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorPalette) private var colorPalette
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference

    enum Destination {
        case editCorrectionRange
        case editInsulinNeeds
    }
    
    fileprivate enum AlertState {
        case confirmDelete
        case trainingIncomplete
    }

    @State private var trainingCompletion: PresetsTrainingCompletion
    @State private var preset: SelectablePreset
    @State private var navigationPath = NavigationPath()
    @State private var isDurationPickerExpanded = false
    @State private var showingDayPicker: Bool = false
    @State private var activeAlert: AlertState?
    
    @FocusState private var isTextFieldFocused: Bool
    
    private var originalPreset: SelectablePreset
    private var scheduledRange: ClosedRange<LoopQuantity>
    private var onSave: (SelectablePreset) throws -> Void
    private var onDelete: (SelectablePreset) throws -> Void
    
    let correctionRangeGuardrailForPreset: (SelectablePreset) -> Guardrail<LoopQuantity>
    let impactForInsulinMultiplier: (Double) -> TherapySettings.InsulinMultiplierImpact
    let showPresetsTrainingSheet: () -> Void
    let suspendThreshold: () -> GlucoseThreshold?
    
    private var scheduleFooter: String? {
        guard preset.repeatOptions != .none,
              let timeString = preset.scheduleStartDate?.formatted(date: .omitted, time: .shortened)
        else { return nil }
        
        return String(
            format: NSLocalizedString(
                "Repeats weekly on %1$@ at %2$@",
                comment: "preset weekly repeat footer (1: repeat day(s)) (2: repeat time)"
            ),
            String(describing: preset.repeatOptions),
            timeString
        )
    }
    
    private var activityPresetIsModified: Bool? {
        guard case let .activity(activityPreset) = preset else { return nil }
        
        return activityPreset.isModifiedFromDefault
    }
    
    public init(
        preset: SelectablePreset,
        scheduledRange: ClosedRange<LoopQuantity>,
        trainingCompletion: PresetsTrainingCompletion,
        onSave: @escaping ((SelectablePreset) throws -> Void),
        onDelete: @escaping ((SelectablePreset) throws -> Void),
        correctionRangeGuardrailForPreset: @escaping (SelectablePreset) -> Guardrail<LoopQuantity>,
        impactForInsulinMultiplier: @escaping (Double) -> TherapySettings.InsulinMultiplierImpact,
        showPresetsTrainingSheet: @escaping () -> Void,
        suspendThreshold: @escaping () -> GlucoseThreshold?
    ) {
        self.preset = preset
        self.originalPreset = preset
        self.scheduledRange = scheduledRange
        self.trainingCompletion = trainingCompletion
        self.onSave = onSave
        self.onDelete = onDelete
        self.correctionRangeGuardrailForPreset = correctionRangeGuardrailForPreset
        self.impactForInsulinMultiplier = impactForInsulinMultiplier
        self.showPresetsTrainingSheet = showPresetsTrainingSheet
        self.suspendThreshold = suspendThreshold
    }
    
    var trainingNeededSection: some View {
        Button {
            showPresetsTrainingSheet()
        } label: {
            CardSection("Temporary Settings Adjustments", borderColor: .accentColor) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Group {
                            Text(Image(systemName: "info.circle"))
                                .foregroundStyle(Color.accentColor) +
                            Text(" Extra Training Needed")
                        }
                        .font(.callout.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Complete the training to change this preset’s settings. You can still update the details.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
    }

    var sensitivitySection: some View {
        Button {
            if !preset.isPreMeal && !trainingCompletion.isComplete {
                activeAlert = .trainingIncomplete
            } else if preset.canAdjustSensitivity {
                navigationPath.append(Destination.editInsulinNeeds)
            }
        } label: {
            CardSection(preset.isPreMeal || trainingCompletion.isComplete ? "Temporary Settings Adjustments" : nil) {
                InsulinNeedsAdjustmentPreview(
                    insulinPercentage: preset.insulinNeedsScaleFactor * 100,
                    guardrail: Guardrail.presetInsulinNeeds,
                    showDisclosure: preset.canAdjustSensitivity
                )
                if (!preset.canAdjustSensitivity) {
                    (Text(Image(systemName: "info.circle")) + Text(" Overall insulin cannot be adjusted for this preset"))
                        .foregroundColor(.secondary)
                        .font(.footnote)
                        .italic()
                        .padding(.top, 4)
                }
            }
            .foregroundColor(.primary)
        }
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollViewReader { scrollViewProxy in
                CardSectionScrollView {
                    presetTitle
                    
                    if !preset.isPreMeal && !trainingCompletion.isComplete {
                        trainingNeededSection
                    }
                    
                    sensitivitySection
                    
                    CardSection {
                        Button {
                            if !preset.isPreMeal && !trainingCompletion.isComplete {
                                activeAlert = .trainingIncomplete
                            } else {
                                navigationPath.append(Destination.editCorrectionRange)
                            }
                        } label: {
                            CorrectionRangePreview(
                                range: preset.correctionRange,
                                guardrail: correctionRangeGuardrailForPreset(preset),
                                scheduledRange: scheduledRange,
                                veryHighInsulinNeeds: preset.veryHighInsulinNeeds,
                                showDisclosure: true
                            )
                        }.accessibilityIdentifier("button_CorrectionRange")
                    }
                    
                    if let activityPresetIsModified {
                        Group {
                            if activityPresetIsModified {
                                Button {
                                    if case let .activity(activityPreset) = preset {
                                        withAnimation {
                                            preset = .activity(ActivityPreset(activityType: activityPreset.activityType, preset: activityPreset.activityType.defaultPreset(duration: activityPreset.preset.duration, scheduleStartDate: activityPreset.preset.scheduleStartDate, repeatOptions: activityPreset.preset.repeatOptions ?? .none)))
                                        }
                                    }
                                } label: {
                                    Group {
                                        Text(Image(systemName: "arrow.uturn.backward")) + Text(" ") + Text("Revert to recommended values")
                                    }
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(ActionButtonStyle(.secondary))
                            } else {
                                Group {
                                    Text(Image(systemName: "checkmark.seal.fill")) + Text(" ") + Text("Recommended starting values")
                                }
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    presetDetailsCard
                    
                    // Duration Section
                    if preset.canAdjustDuration {
                        durationCard(scrollViewProxy)
                    }
                    
                    // Schedule Toggle
                    if preset.allowsScheduling {
                        schedulingCard(scrollViewProxy)
                    }
                    
                    if preset.canBeDeleted {
                        deletePresetButton
                    }
                }
                .animation(.easeInOut, value: preset.duration)
            }
            .navigationBarItems(trailing: dismissButton)
            .navigationDestination(for: Destination.self) { dest in
                switch dest {
                case .editInsulinNeeds:
                    ExistingPresetInsulinNeedsEdit(
                        insulinScaleFactor: $preset.insulinNeedsScaleFactor,
                        presetUsesScheduledRange: preset.correctionRange == nil,
                        impactForInsulinMultiplier: impactForInsulinMultiplier
                    )
                case .editCorrectionRange:
                    ExistingPresetRangeEdit(
                        range: $preset.correctionRange,
                        guardrail: correctionRangeGuardrailForPreset(preset),
                        scheduledRange: scheduledRange,
                        allowsScheduledRange: preset.canAdjustSensitivity,
                        isPreMeal: preset.isPreMeal,
                        presetAdjustsInsulinNeeds: preset.insulinNeedsScaleFactor != 1,
                        veryHighInsulinNeeds: preset.veryHighInsulinNeeds,
                        suspendThresholdQuantity: { suspendThreshold()?.quantity }
                    )
                }
            }
            .onChange(of: preset.scheduleStartDate, { _, newValue in
                if newValue != nil && preset.repeatOptions != .none {
                    assignRepeatDays()
                }
            })
            .onChange(of: preset) { _, _ in
                do {
                    try onSave(preset)
                } catch {
                    print(error)
                }
            }
            .alert(alertTitle, isPresented: isAlertPresented, presenting: activeAlert) { alertState in
                alertActions(for: alertState)
            } message: { alertState in
                alertMessage(for: alertState)
            }
        }
    }
    
    private var presetDetailsCard: some View {
        CardSection("Preset Details") {
            HStack {
                Text("Name")
                Spacer()
                if preset.canChangeName {
                    TextField("", text: $preset.name, prompt: Text("Required"))
                        .multilineTextAlignment(.trailing)
                        .focused($isTextFieldFocused)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        if case let .activity(activityPreset) = preset {
                            Text(Image(systemName: activityPreset.activityType.symbol.value))
                        }
                        
                        Text(preset.name)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func durationCard(_ proxy: ScrollViewProxy) -> some View {
        CardSection {
            VStack(alignment: .leading) {
                HStack {
                    Text("Duration")
                        .foregroundColor(.primary)
                    Spacer()
                    Group {
                        Text(preset.duration.localizedTitle)
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    isTextFieldFocused = false
                    withAnimation {
                        isDurationPickerExpanded.toggle()
                        Task {
                            if isDurationPickerExpanded {
                                try? await Task.sleep(nanoseconds: 200_000_000) // ~0.2s delay
                                withAnimation {
                                    proxy.scrollTo("durationPicker", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                
                if isDurationPickerExpanded {
                    DurationPickerView(
                        durationType: $preset.duration,
                        allowIndefinite: preset.allowsIndefiniteDuration
                    )
                    .id("durationPicker") // Assign an ID for scrolling
                }
            }
        }
        .id("durationSection") // Optional: ID for the entire duration section
    }
        
    private var deletePresetButton: some View {
        Button("Delete Preset") {
            activeAlert = .confirmDelete
        }
        .buttonStyle(ActionButtonStyle(.destructive))
        .padding(.top)
    }

    private func schedulingCard(_ proxy: ScrollViewProxy) -> some View {
        CardSection(content:  {
            HStack {
                Text("Schedule")
                    .font(.body)
                
                Spacer()
                
                Toggle("", isOn: Binding(get: {
                    return preset.isScheduled
                }, set: { newValue in
                    withAnimation {
                        if newValue {
                            preset.scheduleStartDate = Date().addingTimeInterval(.hours(1))
                            Task {
                                try? await Task.sleep(nanoseconds: 200_000_000) // ~0.2s delay
                                withAnimation {
                                    proxy.scrollTo("repeatOption", anchor: .bottom)
                                }
                            }
                        } else {
                            preset.scheduleStartDate = nil
                            preset.repeatOptions = .none
                        }
                    }
                }))
                .toggleStyle(SwitchToggleStyle(tint: .green))
                .labelsHidden()
                .padding(.vertical, -4)
            }
            
            if preset.isScheduled {
                Divider()
                HStack {
                    if preset.repeatOptions != .none {
                        Text("Next Date")
                    } else {
                        Text("Start Date")
                    }
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(get: {
                            preset.nextScheduledStartAfter(Date()) ?? Date()
                        }, set: { newValue in
                            preset.scheduleStartDate = newValue
                        }),
                        in: Date().addingTimeInterval(.minutes(1))...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                Divider()
                    .padding(.top, -4)
                HStack {
                    Text("Repeat")
                    Spacer()
                    Picker("Repeat", selection: Binding<RepeatOption>(
                        get: { preset.repeatOptions == .none ? .never : .weekly },
                        set: { newValue in
                            if newValue == .never {
                                preset.repeatOptions = .none
                            } else {
                                Task {
                                    if let requiredRepeatOption {
                                        preset.repeatOptions = requiredRepeatOption
                                    }
                                    try? await Task.sleep(nanoseconds: 200_000_000) // ~0.2s delay
                                    withAnimation {
                                        proxy.scrollTo("selectedDays", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    ).animation()) {
                        ForEach(RepeatOption.allCases, id: \.self) { option in
                            Text(String(describing: option))
                        }
                    }
                    .tint(.secondary)
                    .pickerStyle(MenuPickerStyle())
                    .padding(.trailing, -8)
                }
                .id("repeatOption") // Assign an ID for scrolling
                
                
                if preset.repeatOptions != .none {
                    Divider()
                        .padding(.top, -4)
                    HStack {
                        Text("Selected days")
                            .foregroundColor(.primary)
                        HStack {
                            Spacer()
                            RepeatOptionView(repeatOptions: preset.repeatOptions)
                                .padding(.vertical, 6)
                                .onTapGesture {
                                    withAnimation {
                                        showingDayPicker = true
                                    }
                                }
                        }
                        .popover(isPresented: $showingDayPicker, arrowEdge: .bottom) {
                            DayPickerPopup(selectedDays: Binding(
                                get: {
                                    preset.repeatOptions
                                }, set: { newValue in
                                    preset.repeatOptions = newValue.union(requiredRepeatOption ?? .none)
                                }))
                            .cornerRadius(12)
                            .presentationCompactAdaptation(.popover)
                        }
                    }
                    .id("selectedDays") // Assign an ID for scrolling
                }
            }
        }, footerText: scheduleFooter)
    }
    
    private var requiredRepeatOption: PresetScheduleRepeatOptions? {
        guard let startDate = preset.scheduleStartDate else { return nil }
        return .allCases[Calendar.current.component(.weekday, from: startDate) - 1]
    }

    func assignRepeatDays() {
        guard let requiredRepeatOption else {
            return
        }
        preset.repeatOptions = requiredRepeatOption
    }

    private var dismissButton: some View {
        Button("Done") {
            dismiss()
        }.bold()
    }

    var presetTitle: some View {
        HStack(spacing: 6) {
            if let icon = preset.icon, !icon.isEmpty {
                PresetSymbolView(icon, iconSize: 34)
            }

            Text(preset.name)
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
    
    private var alertTitle: String {
        switch activeAlert {
        case .confirmDelete: return "Delete “\(preset.name)”?"
        case .trainingIncomplete: return "Extra Training Needed"
        case .none: return ""
        }
    }
    
    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { activeAlert != nil },
            set: { if !$0 { activeAlert = nil } }
        )
    }

    @ViewBuilder
    private func alertActions(for alertState: AlertState) -> some View {
        switch alertState {
        case .confirmDelete:
            Button("Go Back", role: .cancel) {
                activeAlert = nil
            }
            Button("Yes, Delete", role: .destructive) {
                do {
                    try onDelete(preset)
                    dismiss()
                } catch {
                    print(error)
                }
            }
        case .trainingIncomplete:
            Button("Start Training") {
                showPresetsTrainingSheet()
                activeAlert = nil
            }
            Button("Close", role: .cancel) {
                activeAlert = nil
            }
        }
    }
    
    @ViewBuilder
    private func alertMessage(for alertState: AlertState) -> some View {
        switch alertState {
        case .confirmDelete:
            Text("Are you sure you want to delete this preset?")
        case .trainingIncomplete:
            Text("Complete the training to change this preset’s settings.")
        }
    }
}
