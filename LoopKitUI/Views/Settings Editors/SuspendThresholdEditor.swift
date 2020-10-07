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


public struct SuspendThresholdEditor: View {
    var initialValue: HKQuantity?
    var unit: HKUnit
    var maxValue: HKQuantity?
    var save: (_ suspendThreshold: HKQuantity) -> Void
    let mode: PresentationMode
    
    @State private var userDidTap: Bool = false
    @State var value: HKQuantity
    @State var isEditing = false
    @State var showingConfirmationAlert = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.authenticate) var authenticate

    let guardrail = Guardrail.suspendThreshold

    public init(
        value: HKQuantity?,
        unit: HKUnit,
        maxValue: HKQuantity?,
        onSave save: @escaping (_ suspendThreshold: HKQuantity) -> Void,
        mode: PresentationMode = .settings
    ) {
        self._value = State(initialValue: value ?? Self.defaultValue(for: unit))
        self.initialValue = value
        self.unit = unit
        self.maxValue = maxValue
        self.save = save
        self.mode = mode
    }
    
    public init(
           viewModel: TherapySettingsViewModel,
           didSave: (() -> Void)? = nil
    ) {
        self.init(
            value: viewModel.therapySettings.suspendThreshold?.quantity,
            unit: viewModel.glucoseUnit,
            maxValue: Guardrail.maxSuspendThresholdValue(
                correctionRangeSchedule: viewModel.therapySettings.glucoseTargetRangeSchedule,
                preMealTargetRange: viewModel.therapySettings.preMealTargetRange,
                workoutTargetRange: viewModel.therapySettings.workoutTargetRange,
                unit: viewModel.glucoseUnit
            ),
            onSave: { [weak viewModel] newValue in
                let newThreshold = GlucoseThreshold(unit: viewModel!.glucoseUnit, value: newValue.doubleValue(for: viewModel!.glucoseUnit))
                viewModel?.saveSuspendThreshold(value: newThreshold)
                didSave?()
            },
            mode: viewModel.mode
        )
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
            title: Text(TherapySetting.suspendThreshold.title),
            actionButtonTitle: Text(mode.buttonText),
            actionButtonState: saveButtonState,
            cards: {
                // TODO: Remove conditional when Swift 5.3 ships
                // https://bugs.swift.org/browse/SR-11628
                if true {
                    Card {
                        SettingDescription(text: description, informationalContent: { TherapySetting.suspendThreshold.helpScreen() })
                        ExpandableSetting(
                            isEditing: $isEditing,
                            valueContent: {
                                GuardrailConstrainedQuantityView(
                                    value: value,
                                    unit: unit,
                                    guardrail: guardrail,
                                    isEditing: isEditing,
                                    // Workaround for strange animation behavior on appearance
                                    forceDisableAnimations: true
                                )
                            },
                            expandedContent: {
                                GlucoseValuePicker(
                                    value: self.$value.animation(),
                                    unit: self.unit,
                                    guardrail: self.guardrail,
                                    bounds: self.guardrail.absoluteBounds.lowerBound...(self.maxValue ?? self.guardrail.absoluteBounds.upperBound)
                                )
                                // Prevent the picker from expanding the card's width on small devices
                                .frame(maxWidth: UIScreen.main.bounds.width - 48)
                                .clipped()
                            }
                        )
                    }
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
        .navigationBarTitle("", displayMode: .inline)
        .onTapGesture {
            self.userDidTap = true
        }
    }

    var description: Text {
        Text(TherapySetting.suspendThreshold.descriptiveText)
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
        initialValue == nil || value != initialValue! || mode == .acceptanceFlow ? .enabled : .disabled
    }

    private var warningThreshold: SafetyClassification.Threshold? {
        switch guardrail.classification(for: value) {
        case .withinRecommendedRange:
            return nil
        case .outsideRecommendedRange(let threshold):
            return threshold
        }
    }

    private func confirmationAlert() -> SwiftUI.Alert {
        SwiftUI.Alert(
            title: Text("Save Suspend Threshold?", comment: "Alert title for confirming a suspend threshold outside the recommended range"),
            message: Text(TherapySetting.suspendThreshold.guardrailSaveWarningCaption),
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
        authenticate(TherapySetting.suspendThreshold.authenticationChallengeDescription) {
            switch $0 {
            case .success: self.continueSaving()
            case .failure: break
            }
        }
    }
    
    private func continueSaving() {
        self.save(self.value)
    }
}

struct SuspendThresholdGuardrailWarning: View {
    var safetyClassificationThreshold: SafetyClassification.Threshold

    var body: some View {
        GuardrailWarning(title: title, threshold: safetyClassificationThreshold)
    }

    private var title: Text {
        switch safetyClassificationThreshold {
        case .minimum, .belowRecommended:
            return Text("Low Suspend Threshold", comment: "Title text for the low suspend threshold warning")
        case .aboveRecommended, .maximum:
            return Text("High Suspend Threshold", comment: "Title text for the high suspend threshold warning")
        }
    }
}

struct SuspendThresholdView_Previews: PreviewProvider {
    static var previews: some View {
        SuspendThresholdEditor(value: nil, unit: .milligramsPerDeciliter, maxValue: nil, onSave: { _ in })
    }
}
