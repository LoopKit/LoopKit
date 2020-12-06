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
    let suspendThreshold: GlucoseThreshold?
    let unit: HKUnit
    var correctionRangeScheduleRange: ClosedRange<HKQuantity>
    var minValue: HKQuantity?
    var save: (_ overrides: CorrectionRangeOverrides) -> Void
    var sensitivityOverridesEnabled: Bool
    var mode: SettingsPresentationMode

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

    fileprivate init(
        value: CorrectionRangeOverrides,
        preset: CorrectionRangeOverrides.Preset,
        unit: HKUnit,
        correctionRangeScheduleRange: ClosedRange<HKQuantity>,
        minValue: HKQuantity?,
        onSave save: @escaping (_ overrides: CorrectionRangeOverrides) -> Void,
        sensitivityOverridesEnabled: Bool,
        suspendThreshold: GlucoseThreshold?,
        mode: SettingsPresentationMode = .settings
    ) {
        self._value = State(initialValue: value)
        self.initialValue = value
        self.preset = preset
        self.unit = unit
        self.correctionRangeScheduleRange = correctionRangeScheduleRange
        self.minValue = minValue
        self.save = save
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.suspendThreshold = suspendThreshold
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
                unit: viewModel.therapySettings.glucoseUnit!
            ),
            preset: preset,
            unit: viewModel.therapySettings.glucoseUnit!,
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
            suspendThreshold: viewModel.therapySettings.suspendThreshold,
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
        Button(action: { self.dismiss() } ) { Text(LocalizedString("Cancel", comment: "Cancel editing settings button title")) }
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
                suspendThreshold: suspendThreshold,
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
        return Guardrail.correctionRangeOverride(for: preset, correctionRangeScheduleRange: correctionRangeScheduleRange,
                                                 suspendThreshold: suspendThreshold)
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
        guardrail(for: preset).absoluteBounds
    }

    private func initiallySelectedValue(for preset: CorrectionRangeOverrides.Preset) -> ClosedRange<HKQuantity> {
        guardrail(for: preset).recommendedBounds.clamped(to: selectableBounds(for: preset))
    }

    private var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.crossedThresholds
        return Group {
            if !crossedThresholds.isEmpty && (userDidTap || mode == .settings) {
                CorrectionRangeOverridesGuardrailWarning(crossedThresholds: crossedThresholds, preset: preset)
            }
        }
    }

    private var crossedThresholds: [SafetyClassification.Threshold] {
        guard let range = value.ranges[preset] else { return [] }
        
        let guardrail = self.guardrail(for: preset)
        let thresholds: [SafetyClassification.Threshold] = [range.lowerBound, range.upperBound].compactMap { bound in
            switch guardrail.classification(for: bound) {
            case .withinRecommendedRange:
                return nil
            case .outsideRecommendedRange(let threshold):
                return threshold
            }
        }
        
        return thresholds
    }

    private func confirmationAlert() -> SwiftUI.Alert {
        let title: Text
        switch preset {
        case .preMeal:
            title = Text(LocalizedString("Save Pre-Meal Range?", comment: "Alert title for confirming pre-meal range overrides outside the recommended range"))
        case .workout:
            title = Text(LocalizedString("Save Workout Range?", comment: "Alert title for confirming workout range overrides outside the recommended range"))
        }
        
        return SwiftUI.Alert(
            title: title,
            // For the message, preMeal and workout are the same
            message: Text(TherapySetting.preMealCorrectionRangeOverride.guardrailSaveWarningCaption),
            primaryButton: .cancel(Text(LocalizedString("Go Back", comment: "Text for go back action on confirmation alert"))),
            secondaryButton: .default(
                Text(LocalizedString("Continue", comment: "Text for continue action on confirmation alert")),
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
    var crossedThresholds: [SafetyClassification.Threshold]
    var preset: CorrectionRangeOverrides.Preset
    
    var body: some View {
        assert(!crossedThresholds.isEmpty)
        return GuardrailWarning(
            title: title,
            thresholds: crossedThresholds,
            caption: caption
        )
    }

    private var title: Text {
        if crossedThresholds.count == 1 {
            return singularWarningTitle(for: crossedThresholds.first!)
        } else {
            return multipleWarningTitle
        }
    }

    private func singularWarningTitle(for threshold: SafetyClassification.Threshold) -> Text {
        switch threshold {
        case .minimum, .belowRecommended:
            switch preset {
            case .preMeal:
                return Text(LocalizedString("Low Pre-Meal Value", comment: "Title text for the low pre-meal value warning"))
            case .workout:
                return Text(LocalizedString("Low Workout Value", comment: "Title text for the low workout value warning"))
            }
        case .aboveRecommended, .maximum:
            switch preset {
            case .preMeal:
                return Text(LocalizedString("High Pre-Meal Value", comment: "Title text for the low pre-meal value warning"))
            case .workout:
                return Text(LocalizedString("High Workout Value", comment: "Title text for the high workout value warning"))
            }
        }
    }

    private var multipleWarningTitle: Text {
        switch preset {
        case .preMeal:
            return Text(LocalizedString("Pre-Meal Values", comment: "Title text for multi-value pre-meal value warning"))
        case .workout:
            return Text(LocalizedString("Workout Values", comment: "Title text for multi-value workout value warning"))
        }
    }

    var caption: Text? {
        guard
            preset == .preMeal,
            crossedThresholds.allSatisfy({ $0 == .aboveRecommended || $0 == .maximum })
        else {
            return nil
        }
        
        return Text(crossedThresholds.count > 1 ? TherapySetting.preMealCorrectionRangeOverride.guardrailCaptionForOutsideValues : TherapySetting.preMealCorrectionRangeOverride.guardrailCaptionForHighValue)
    }
}

public extension CorrectionRangeOverrides.Preset {
    
    var descriptiveText: String {
        switch self {
        case .preMeal:
            return LocalizedString("Temporarily lower your glucose target before a meal to impact post-meal glucose spikes.", comment: "Description of pre-meal mode")
        case .workout:
            return LocalizedString("Temporarily raise your glucose target before, during, or after physical activity to reduce the risk of low glucose events.", comment: "Description of workout mode")
        }
    }

}
