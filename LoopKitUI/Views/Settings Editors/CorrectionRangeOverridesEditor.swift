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
    let initialValue: CorrectionRangeOverrides
    let preset: CorrectionRangeOverrides.Preset
    let unit: HKUnit
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
        preset: CorrectionRangeOverrides.Preset,
        unit: HKUnit,
        correctionRangeScheduleRange: ClosedRange<HKQuantity>,
        minValue: HKQuantity?,
        onSave save: @escaping (_ overrides: CorrectionRangeOverrides) -> Void,
        sensitivityOverridesEnabled: Bool,
        mode: PresentationMode = .settings
    ) {
        self._value = State(initialValue: value)
        self.initialValue = value
        self.preset = preset
        self.unit = unit
        self.correctionRangeScheduleRange = correctionRangeScheduleRange
        self.minValue = minValue
        self.save = save
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.mode = mode
    }
    
    public init(
        viewModel: TherapySettingsViewModel,
        preset: CorrectionRangeOverrides.Preset,
        didSave: (() -> Void)? = nil
    ) {
        self.init(
            value: CorrectionRangeOverrides(
                preMeal: viewModel.therapySettings.preMealTargetRange,
                workout: viewModel.therapySettings.workoutTargetRange,
                unit: viewModel.glucoseUnit
            ),
            preset: preset,
            unit: viewModel.glucoseUnit,
            correctionRangeScheduleRange: viewModel.therapySettings.glucoseTargetRangeSchedule!.scheduleRange(),
            minValue: viewModel.therapySettings.suspendThreshold?.quantity,
            onSave: { [weak viewModel] overrides in
                let glucoseUnit = viewModel?.therapySettings.glucoseUnit ?? .milligramsPerDeciliter
                switch preset {
                case .preMeal:
                    viewModel?.saveCorrectionRangeOverride(preMeal: overrides.preMeal, unit: glucoseUnit)
                case .workout:
                    viewModel?.saveCorrectionRangeOverride(workout: overrides.workout, unit: glucoseUnit)
                }
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
            title: Text(preset.therapySetting.title),
            actionButtonTitle: Text(mode.buttonText),
            actionButtonState: value != initialValue || mode == .acceptanceFlow ? .enabled : .disabled,
            cards: {
                // TODO: Figure out why I need to explicitly return a CardStack with 1 card here
                CardStack(cards: [card(for: preset)])
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
            SettingDescription(text: description(of: preset), informationalContent: { preset.therapySetting.helpScreen() })
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
        return Guardrail.correctionRangeOverride(for: preset, correctionRangeScheduleRange: correctionRangeScheduleRange)
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
            .foregroundColor(.secondary)
            .font(.subheadline)
            Spacer()
        }
    }

    private func selectableBounds(for preset: CorrectionRangeOverrides.Preset) -> ClosedRange<HKQuantity> {
        switch preset {
        case .preMeal:
            if let minValue = minValue {
                return max(minValue, Guardrail.correctionRange.absoluteBounds.lowerBound)...Guardrail.correctionRange.absoluteBounds.upperBound
            } else {
                return Guardrail.correctionRange.absoluteBounds.lowerBound...Guardrail.correctionRange.absoluteBounds.upperBound
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
            if !crossedThresholds.isEmpty && (userDidTap || mode == .settings) {
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
            .filter { $0.key == preset }
    }

    private func confirmationAlert() -> SwiftUI.Alert {
        SwiftUI.Alert(
            title: Text("Save Correction Range Overrides?", comment: "Alert title for confirming correction range overrides outside the recommended range"),
            // For the message, preMeal and workout are the same
            message: Text(TherapySetting.preMealCorrectionRangeOverride.guardrailSaveWarningCaption),
            primaryButton: .cancel(Text("Go Back")),
            secondaryButton: .default(
                Text("Continue"),
                action: startSaving
            )
        )
    }
    
    private func startSaving() {
        guard mode == .settings else {
            self.continueSaving()
            return
        }
        authenticate(preset.therapySetting.authenticationChallengeDescription) {
            switch $0 {
            case .success: self.continueSaving()
            case .failure: break
            }
        }
    }
    
    private func continueSaving() {
        self.save(self.value)
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
            let crossedPreMealThresholds = crossedThresholds[.preMeal],
            crossedPreMealThresholds.allSatisfy({ $0 == .aboveRecommended || $0 == .maximum })
        else {
            return nil
        }
        
        return Text(crossedPreMealThresholds.count > 1 ? TherapySetting.preMealCorrectionRangeOverride.guardrailCaptionForOutsideValues : TherapySetting.preMealCorrectionRangeOverride.guardrailCaptionForHighValue)
    }
}
