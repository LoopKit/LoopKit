//
//  CorrectionRangeOverridesEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit

public struct CorrectionRangeOverridesEditor: View {
    var initialValue: CorrectionRangeOverrides
    var unit: HKUnit
    var correctionRangeScheduleRange: ClosedRange<HKQuantity>
    var minValue: HKQuantity?
    var save: (_ overrides: CorrectionRangeOverrides) -> Void
    var sensitivityOverridesEnabled: Bool
    var mode: PresentationMode

    @State private var userDidTap: Bool = false

    @State var value: CorrectionRangeOverrides

    @State var presetBeingEdited: CorrectionRangeOverrides.Preset? {
        didSet {
            if let presetBeingEdited = presetBeingEdited, value.ranges[presetBeingEdited] == nil {
                value.ranges[presetBeingEdited] = initiallySelectedValue(for: presetBeingEdited)
            }
        }
    }

    @State var showingConfirmationAlert = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.authenticate) var authenticate

    public init(
        value: CorrectionRangeOverrides,
        unit: HKUnit,
        correctionRangeScheduleRange: ClosedRange<HKQuantity>,
        minValue: HKQuantity?,
        onSave save: @escaping (_ overrides: CorrectionRangeOverrides) -> Void,
        sensitivityOverridesEnabled: Bool,
        mode: PresentationMode = .legacySettings
    ) {
        self._value = State(initialValue: value)
        self.initialValue = value
        self.unit = unit
        self.correctionRangeScheduleRange = correctionRangeScheduleRange
        self.minValue = minValue
        self.save = save
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.mode = mode
    }
    
    public init(
        viewModel: TherapySettingsViewModel,
        didSave: (() -> Void)? = nil
    ) {
        self.init(
            value: CorrectionRangeOverrides(
                preMeal: viewModel.therapySettings.preMealTargetRange,
                workout: viewModel.therapySettings.workoutTargetRange,
                unit: viewModel.therapySettings.glucoseUnit!
            ),
            unit: viewModel.therapySettings.glucoseUnit!,
            correctionRangeScheduleRange: viewModel.therapySettings.glucoseTargetRangeSchedule!.scheduleRange(),
            minValue: viewModel.therapySettings.suspendThreshold?.quantity,
            onSave: { [weak viewModel] overrides in
                viewModel?.saveCorrectionRangeOverrides(overrides: overrides, unit: viewModel?.therapySettings.glucoseUnit ?? .milligramsPerDeciliter)
                didSave?()
            },
            sensitivityOverridesEnabled: viewModel.sensitivityOverridesEnabled,
            mode: viewModel.mode
        )
    }

    public var body: some View {
        switch mode {
        case .settings: return AnyView(contentWithCancel)
        case .acceptanceFlow: return AnyView(content)
        case .legacySettings: return AnyView(content)
        }
    }
    
    private var contentWithCancel: some View {
        if value == initialValue {
            return AnyView(content
                .navigationBarBackButtonHidden(false)
                .navigationBarItems(leading: EmptyView())
            )
        } else {
            return AnyView(content
                .navigationBarBackButtonHidden(true)
                .navigationBarItems(leading: cancelButton)
            )
        }
    }
    
    private var cancelButton: some View {
        Button(action: { self.dismiss() } ) { Text("Cancel", comment: "Cancel editing settings button title") }
    }
    
    private var content: some View {
        ConfigurationPage(
            title: Text(TherapySetting.correctionRangeOverrides.smallTitle),
            actionButtonTitle: Text(mode.buttonText),
            actionButtonState: value != initialValue || mode == .acceptanceFlow ? .enabled : .disabled,
            cards: {
                card(for: .preMeal)
                if !sensitivityOverridesEnabled {
                    card(for: .workout)
                }
            },
            actionAreaContent: {
                instructionalContentIfNecessary
                guardrailWarningIfNecessary
            },
            action: {
                if self.crossedThresholds.isEmpty {
                    self.startSaving()
                } else {
                    self.showingConfirmationAlert = true
                }
            }
        )
        .alert(isPresented: $showingConfirmationAlert, content: confirmationAlert)
        .navigationBarTitle("", displayMode: .inline)
        .onTapGesture {
            self.userDidTap = true
        }
    }

    private func card(for preset: CorrectionRangeOverrides.Preset) -> Card {
        Card {
            SettingDescription(text: description(of: preset), informationalContent: {TherapySetting.correctionRangeOverrides.helpScreen()})
            CorrectionRangeOverridesExpandableSetting(
                isEditing: Binding(
                    get: { self.presetBeingEdited == preset },
                    set: { isEditing in
                        withAnimation {
                            self.presetBeingEdited = isEditing ? preset : nil
                        }
                }),
                value: $value,
                preset: preset,
                unit: unit,
                correctionRangeScheduleRange: correctionRangeScheduleRange,
                expandedContent: {
                    GlucoseRangePicker(
                        range: Binding(
                            get: { self.value.ranges[preset] ?? self.initiallySelectedValue(for: preset) },
                            set: { newValue in
                                withAnimation {
                                    self.value.ranges[preset] = newValue
                                }
                        }
                        ),
                        unit: self.unit,
                        minValue: self.selectableBounds(for: preset).lowerBound,
                        maxValue: self.selectableBounds(for: preset).upperBound,
                        guardrail: self.guardrail(for: preset)
                    )
                    .accessibility(identifier: "\(self.accessibilityIdentifier(for: preset))_picker")
            })
        }
    }

    private func description(of preset: CorrectionRangeOverrides.Preset) -> Text {
        switch preset {
        case .preMeal:
            return Text(preset.descriptiveText)
        case .workout:
            return Text(preset.descriptiveText)
        }
    }
    
    private func guardrail(for preset: CorrectionRangeOverrides.Preset) -> Guardrail<HKQuantity> {
        return Guardrail.correctionRangeOverridePreset(preset, correctionRangeScheduleRange: correctionRangeScheduleRange)
    }
    
    private var instructionalContentIfNecessary: some View {
        return Group {
            if mode == .acceptanceFlow && !userDidTap {
                instructionalContent
            }
        }
    }

    private var instructionalContent: some View {
        HStack { // to align with guardrail warning, if present
            Text(LocalizedString("You can edit a setting by tapping into any line item.", comment: "Description of how to edit setting"))
            .foregroundColor(.instructionalContent)
            .font(.subheadline)
            Spacer()
        }
    }

    private func selectableBounds(for preset: CorrectionRangeOverrides.Preset) -> ClosedRange<HKQuantity> {
        switch preset {
        case .preMeal:
            if let minValue = minValue {
                return max(minValue, Guardrail.correctionRange.absoluteBounds.lowerBound)...correctionRangeScheduleRange.upperBound
            } else {
                return Guardrail.correctionRange.absoluteBounds.lowerBound...correctionRangeScheduleRange.upperBound
            }
        case .workout:
            if let minValue = minValue {
                return max(minValue, correctionRangeScheduleRange.upperBound)...Guardrail.correctionRange.absoluteBounds.upperBound
            } else {
                return correctionRangeScheduleRange.upperBound...Guardrail.correctionRange.absoluteBounds.upperBound
            }
        }
    }

    private func initiallySelectedValue(for preset: CorrectionRangeOverrides.Preset) -> ClosedRange<HKQuantity> {
        guardrail(for: preset).recommendedBounds.clamped(to: selectableBounds(for: preset))
    }

    private var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.crossedThresholds
        return Group {
            if !crossedThresholds.isEmpty && (userDidTap || mode == .settings || mode == .legacySettings) {
                CorrectionRangeOverridesGuardrailWarning(crossedThresholds: crossedThresholds)
            }
        }
    }

    private var crossedThresholds: [CorrectionRangeOverrides.Preset: [SafetyClassification.Threshold]] {
        value.ranges
            .compactMapValuesWithKeys { preset, range in
                let guardrail = self.guardrail(for: preset)
                let thresholds: [SafetyClassification.Threshold] = [range.lowerBound, range.upperBound].compactMap { bound in
                    switch guardrail.classification(for: bound) {
                    case .withinRecommendedRange:
                        return nil
                    case .outsideRecommendedRange(let threshold):
                        return threshold
                    }
                }

                return thresholds.isEmpty ? nil : thresholds
            }
    }

    private func confirmationAlert() -> SwiftUI.Alert {
        SwiftUI.Alert(
            title: Text("Save Correction Range Overrides?", comment: "Alert title for confirming correction range overrides outside the recommended range"),
            message: Text("One or more of the values you have entered are outside of what Tidepool generally recommends.", comment: "Alert message for confirming correction range overrides outside the recommended range"),
            primaryButton: .cancel(Text("Go Back")),
            secondaryButton: .default(
                Text("Continue"),
                action: startSaving
            )
        )
    }
    
    private func startSaving() {
        guard mode == .settings || mode == .legacySettings else {
            self.continueSaving()
            return
        }
        authenticate(LocalizedString("Authenticate to change setting", comment: "Authentication hint string")) {
            switch $0 {
            case .success: self.continueSaving()
            case .failure: break
            }
        }
    }
    
    private func continueSaving() {
        self.save(self.value)
        if self.mode == .legacySettings {
            self.dismiss()
        }
    }

    private func accessibilityIdentifier(for preset: CorrectionRangeOverrides.Preset) -> String {
        switch preset {
        case .preMeal:
            return "pre-meal"
        case .workout:
            return "workout"
        }
    }
}

private struct CorrectionRangeOverridesGuardrailWarning: View {
    var crossedThresholds: [CorrectionRangeOverrides.Preset: [SafetyClassification.Threshold]]

    var body: some View {
        assert(!crossedThresholds.isEmpty)
        return GuardrailWarning(
            title: title,
            thresholds: Array(crossedThresholds.values.flatMap { $0 }),
            caption: caption
        )
    }

    private var title: Text {
        if crossedThresholds.count == 1, crossedThresholds.values.first!.count == 1 {
            return singularWarningTitle(for: crossedThresholds.values.first!.first!)
        } else {
            return multipleWarningTitle
        }
    }

    private func singularWarningTitle(for threshold: SafetyClassification.Threshold) -> Text {
        switch threshold {
        case .minimum, .belowRecommended:
            return Text("Low Correction Value", comment: "Title text for the low correction value warning")
        case .aboveRecommended, .maximum:
            return Text("High Correction Value", comment: "Title text for the high correction value warning")
        }
    }

    private var multipleWarningTitle: Text {
        Text("Correction Values", comment: "Title text for multi-value correction value warning")
    }

    var caption: Text? {
        guard
            crossedThresholds.count == 1,
            let crossedPreMealThresholds = crossedThresholds[.preMeal]
        else {
            return nil
        }

        return crossedPreMealThresholds.allSatisfy { $0 == .aboveRecommended || $0 == .maximum }
            ? Text("The value you have entered for this range is higher than your usual correction range. Tidepool typically recommends your pre-meal range be lower than your usual correction range.", comment: "Warning text for high pre-meal target value")
            : nil
    }
}
