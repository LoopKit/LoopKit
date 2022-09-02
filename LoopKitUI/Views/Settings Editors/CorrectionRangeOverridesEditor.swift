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
    @EnvironmentObject private var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable
    @Environment(\.dismissAction) var dismiss
    @Environment(\.authenticate) var authenticate

    let mode: SettingsPresentationMode
    let viewModel: CorrectionRangeOverridesEditorViewModel

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

    var initialValue: CorrectionRangeOverrides {
        viewModel.correctionRangeOverrides
    }

    var preset: CorrectionRangeOverrides.Preset {
        viewModel.preset
    }

    var displayGlucoseUnit: HKUnit {
        displayGlucoseUnitObservable.displayGlucoseUnit
    }
    
    public init(
        mode: SettingsPresentationMode,
        therapySettingsViewModel: TherapySettingsViewModel,
        preset: CorrectionRangeOverrides.Preset,
        didSave: (() -> Void)? = nil
    ) {
        self.mode = mode
        let viewModel = CorrectionRangeOverridesEditorViewModel(
            therapySettingsViewModel: therapySettingsViewModel,
            preset: preset,
            didSave: didSave)
        self._value = State(initialValue: viewModel.correctionRangeOverrides)
        self.viewModel = viewModel
    }

    public var body: some View {
        switch mode {
        case .acceptanceFlow:
            content
        case .settings:
            contentWithCancel
                .navigationBarTitle("", displayMode: .inline)
        }
    }

    private var shouldAddCancelButton: Bool {
        return value != initialValue
    }

    @ViewBuilder
    private var leadingNavigationBarItem: some View {
        if shouldAddCancelButton {
            cancelButton
        } else {
            EmptyView()
        }
    }

    private var contentWithCancel: some View {
        content
            .navigationBarBackButtonHidden(shouldAddCancelButton)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingNavigationBarItem
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    deleteButton
                }
            }
    }

    private var deleteButton: some View {
        Button( action: {
                value.ranges = [:];
                presetBeingEdited = nil
        } )
        { Text(LocalizedString("Delete", comment: "Delete values for Pre-Meal, inactivates Pre-Meal icon")) }
    }
    
    private var cancelButton: some View {
        Button(action: { self.dismiss() } ) { Text(LocalizedString("Cancel", comment: "Cancel editing settings button title")) }
    }
    
    private var content: some View {
        ConfigurationPage(
            title: Text(preset.therapySetting.title),
            actionButtonTitle: Text(mode.buttonText()),
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
        .simultaneousGesture(TapGesture().onEnded {
            withAnimation {
                self.userDidTap = true
            }
        })
    }

    private func card(for preset: CorrectionRangeOverrides.Preset) -> Card {
        Card {
            SettingDescription(text: description(of: preset), informationalContent: { preset.therapySetting.helpScreen() })
            CorrectionRangeOverridesExpandableSetting(
                isEditing: Binding(
                    get: { presetBeingEdited == preset },
                    set: { isEditing in
                        withAnimation {
                            presetBeingEdited = isEditing ? preset : nil
                        }
                }),
                value: $value,
                preset: preset,
                unit: displayGlucoseUnit,
                suspendThreshold: viewModel.suspendThreshold,
                correctionRangeScheduleRange: viewModel.correctionRangeScheduleRange,
                expandedContent: {
                    GlucoseRangePicker(
                        range: Binding(
                            get: { value.ranges[preset] ?? initiallySelectedValue(for: preset) },
                            set: { newValue in
                                withAnimation {
                                    value.ranges[preset] = newValue
                                }
                        }
                        ),
                        unit:
                            displayGlucoseUnit,
                        minValue: selectableBounds(for: preset).lowerBound,
                        maxValue: selectableBounds(for: preset).upperBound,
                        guardrail: viewModel.guardrail
                    )
                    .accessibility(identifier: "\(accessibilityIdentifier(for: preset))_picker")
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
        viewModel.guardrail.absoluteBounds
    }

    private func initiallySelectedValue(for preset: CorrectionRangeOverrides.Preset) -> ClosedRange<HKQuantity> {
        viewModel.guardrail.recommendedBounds.clamped(to: selectableBounds(for: preset))
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
        
        let guardrail = viewModel.guardrail
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
        viewModel.saveCorrectionRangeOverride(value)
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
            therapySetting: preset == .preMeal ? .preMealCorrectionRangeOverride : .workoutCorrectionRangeOverride,
            title: title,
            thresholds: crossedThresholds)
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
