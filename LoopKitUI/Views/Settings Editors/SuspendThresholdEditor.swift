//
//  SuspendThresholdEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit

// Also known as "Glucose Safety Limit"
public struct SuspendThresholdEditor: View {
    @EnvironmentObject private var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable

    @Environment(\.dismissAction) var dismiss
    @Environment(\.authenticate) var authenticate
    @Environment(\.appName) private var appName

    let mode: SettingsPresentationMode
    let viewModel: SuspendThresholdEditorViewModel

    @State private var userDidTap: Bool = false
    @State var value: HKQuantity
    @State var isEditing = false
    @State var showingConfirmationAlert = false

    private var initialValue: HKQuantity? {
        viewModel.suspendThreshold
    }

    public init(
        mode: SettingsPresentationMode,
        therapySettingsViewModel: TherapySettingsViewModel,
        didSave: (() -> Void)? = nil
    ) {
        self.mode = mode
        let viewModel = SuspendThresholdEditorViewModel(therapySettingsViewModel: therapySettingsViewModel,
                                                        mode: mode,
                                                        didSave: didSave)
        self._value = State(initialValue: viewModel.suspendThreshold ?? Self.defaultValue(for: viewModel.suspendThresholdUnit))
        self.viewModel = viewModel
    }

    private static func defaultValue(for unit: HKUnit) -> HKQuantity {
        switch unit {
        case .milligramsPerDeciliter:
            return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)
        case .millimolesPerLiter:
            return HKQuantity(unit: .millimolesPerLiter, doubleValue: 4.5)
        default:
            fatalError("Unsupported glucose unit \(unit)")
        }
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

    private var picker: GlucoseValuePicker {
        GlucoseValuePicker(
            value: self.$value.animation(),
            unit: displayGlucoseUnitObservable.displayGlucoseUnit,
            guardrail: viewModel.guardrail,
            bounds: viewModel.guardrail.absoluteBounds.lowerBound...viewModel.maxSuspendThresholdValue
        )
    }
    
    private var content: some View {
        ConfigurationPage(
            title: Text(TherapySetting.suspendThreshold.title),
            actionButtonTitle: Text(mode.buttonText()),
            actionButtonState: saveButtonState,
            cards: {
                Card {
                    SettingDescription(text: description, informationalContent: { TherapySetting.suspendThreshold.helpScreen() })
                    ExpandableSetting(
                        isEditing: $isEditing,
                        valueContent: {
                            GuardrailConstrainedQuantityView(
                                value: value,
                                unit: displayGlucoseUnitObservable.displayGlucoseUnit,
                                guardrail: viewModel.guardrail,
                                isEditing: isEditing,
                                // Workaround for strange animation behavior on appearance
                                forceDisableAnimations: true
                            )
                        },
                        expandedContent: {
                            // Prevent the picker from expanding the card's width on small devices
                            picker.frame(maxWidth: 200)
                        }
                    )
                }
            },
            actionAreaContent: {
                instructionalContentIfNecessary
                if warningThreshold != nil && (userDidTap || mode != .acceptanceFlow) {
                    SuspendThresholdGuardrailWarning(safetyClassificationThreshold: warningThreshold!)
                }
            },
            action: {
                if self.warningThreshold == nil {
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

    var description: Text {
        Text(TherapySetting.suspendThreshold.descriptiveText(appName: appName))
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
            Text(LocalizedString("You can edit the setting by tapping into the line item.", comment: "Description of how to edit setting"))
            .foregroundColor(.secondary)
            .font(.subheadline)
            Spacer()
        }
    }

    private var saveButtonState: ConfigurationPageActionButtonState {
        let selectableValues = picker.selectableValues
        let adjustedBounds = (selectableValues.first!)...(selectableValues.last!)
        guard adjustedBounds.contains(value.doubleValue(for: displayGlucoseUnitObservable.displayGlucoseUnit)) else {
            return .disabled
        }
        return initialValue == nil || value != initialValue || mode == .acceptanceFlow ? .enabled : .disabled
    }

    private var warningThreshold: SafetyClassification.Threshold? {
        switch viewModel.guardrail.classification(for: value) {
        case .withinRecommendedRange:
            return nil
        case .outsideRecommendedRange(let threshold):
            return threshold
        }
    }

    private func confirmationAlert() -> SwiftUI.Alert {
        SwiftUI.Alert(
            title: Text(LocalizedString("Save Glucose Safety Limit?", comment: "Alert title for confirming a glucose safety limit outside the recommended range")),
            message: Text(TherapySetting.suspendThreshold.guardrailSaveWarningCaption),
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
        authenticate(TherapySetting.suspendThreshold.authenticationChallengeDescription) {
            switch $0 {
            case .success: self.continueSaving()
            case .failure: break
            }
        }
    }
    
    private func continueSaving() {
        viewModel.saveSuspendThreshold(self.value, displayGlucoseUnitObservable.displayGlucoseUnit)
    }
}

struct SuspendThresholdGuardrailWarning: View {
    var safetyClassificationThreshold: SafetyClassification.Threshold

    var body: some View {
        GuardrailWarning(therapySetting: .suspendThreshold, title: title, threshold: safetyClassificationThreshold)
    }

    private var title: Text {
        switch safetyClassificationThreshold {
        case .minimum, .belowRecommended:
            return Text(LocalizedString("Low Glucose Safety Limit", comment: "Title text for the low glucose safety limit warning"))
        case .aboveRecommended, .maximum:
            return Text(LocalizedString("High Glucose Safety Limit", comment: "Title text for the high glucose safety limit warning"))
        }
    }
}

struct SuspendThresholdView_Previews: PreviewProvider {
    static var previews: some View {
        let therapySettingsViewModel = TherapySettingsViewModel(therapySettings: TherapySettings())
        return SuspendThresholdEditor(mode: .settings, therapySettingsViewModel: therapySettingsViewModel, didSave: nil)
            .environmentObject(DisplayGlucoseUnitObservable(displayGlucoseUnit: .milligramsPerDeciliter))
    }
}
