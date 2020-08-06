//
//  DeliveryLimitsEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 6/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


public struct DeliveryLimitsEditor: View {
    var initialValue: DeliveryLimits
    var supportedBasalRates: [Double]
    var selectableBasalRates: [Double]
    var scheduledBasalRange: ClosedRange<Double>?
    var supportedBolusVolumes: [Double]
    var save: (_ deliveryLimits: DeliveryLimits) -> Void
    let mode: PresentationMode

    @State var value: DeliveryLimits
    @State private var userDidTap: Bool = false
    @State var settingBeingEdited: DeliveryLimits.Setting?

    @State var showingConfirmationAlert = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.authenticate) var authenticate

    public init(
        value: DeliveryLimits,
        supportedBasalRates: [Double],
        scheduledBasalRange: ClosedRange<Double>?,
        supportedBolusVolumes: [Double],
        onSave save: @escaping (_ deliveryLimits: DeliveryLimits) -> Void,
        mode: PresentationMode = .legacySettings
    ) {
        self._value = State(initialValue: value)
        self.initialValue = value
        self.supportedBasalRates = supportedBasalRates
        if let maximumScheduledBasalRate = scheduledBasalRange?.upperBound {
            self.selectableBasalRates = Array(supportedBasalRates.drop(while: { $0 < maximumScheduledBasalRate }))
        } else {
            self.selectableBasalRates = supportedBasalRates
        }
        self.scheduledBasalRange = scheduledBasalRange
        self.supportedBolusVolumes = supportedBolusVolumes
        self.save = save
        self.mode = mode
    }
    
    public init(
           viewModel: TherapySettingsViewModel,
           didSave: (() -> Void)? = nil
    ) {
        precondition(viewModel.pumpSupportedIncrements != nil)
        let maxBasal = HKQuantity(unit: .internationalUnitsPerHour, doubleValue: viewModel.therapySettings.maximumBasalRatePerHour!)
        let maxBolus = HKQuantity(unit: .internationalUnit(), doubleValue: viewModel.therapySettings.maximumBolus!)
        
        self.init(
            value: DeliveryLimits(maximumBasalRate: maxBasal, maximumBolus: maxBolus),
            supportedBasalRates: viewModel.pumpSupportedIncrements!.basalRates,
            scheduledBasalRange: viewModel.therapySettings.basalRateSchedule?.valueRange(),
            supportedBolusVolumes: viewModel.pumpSupportedIncrements!.bolusVolumes,
            onSave: { [weak viewModel] newLimits in
                viewModel?.saveDeliveryLimits(limits: newLimits)
                didSave?()
            },
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
            title: Text(TherapySetting.deliveryLimits.title),
            actionButtonTitle: Text(mode.buttonText),
            actionButtonState: saveButtonState,
            cards: {
                maximumBasalRateCard
                maximumBolusCard
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

    var saveButtonState: ConfigurationPageActionButtonState {
        guard value.maximumBasalRate != nil, value.maximumBolus != nil else {
            return .disabled
        }
        
        if mode == .acceptanceFlow {
            return .enabled
        }

        return value == initialValue && mode != .acceptanceFlow ? .disabled : .enabled
    }

    var maximumBasalRateGuardrail: Guardrail<HKQuantity> {
        return Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange)
    }

    var maximumBasalRateCard: Card {
        Card {
            SettingDescription(text: Text(DeliveryLimits.Setting.maximumBasalRate.descriptiveText), informationalContent: { TherapySetting.deliveryLimits.helpScreen() })
            ExpandableSetting(
                isEditing: Binding(
                    get: { self.settingBeingEdited == .maximumBasalRate },
                    set: { isEditing in
                        withAnimation {
                            self.settingBeingEdited = isEditing ? .maximumBasalRate : nil
                        }
                    }
                ),
                leadingValueContent: {
                    Text(DeliveryLimits.Setting.maximumBasalRate.title)
                },
                trailingValueContent: {
                    GuardrailConstrainedQuantityView(
                        value: value.maximumBasalRate,
                        unit: .internationalUnitsPerHour,
                        guardrail: maximumBasalRateGuardrail,
                        isEditing: settingBeingEdited == .maximumBasalRate,
                        forceDisableAnimations: true
                    )
                },
                expandedContent: {
                    FractionalQuantityPicker(
                        value: Binding(
                            get: { self.value.maximumBasalRate ?? self.maximumBasalRateGuardrail.recommendedBounds.upperBound },
                            set: { newValue in
                                withAnimation {
                                    self.value.maximumBasalRate = newValue
                                }
                            }
                        ),
                        unit: .internationalUnitsPerHour,
                        guardrail: self.maximumBasalRateGuardrail,
                        selectableValues: self.selectableBasalRates,
                        usageContext: .independent
                    )
                    .accessibility(identifier: "max_basal_picker")
                }
            )
        }
    }

    var maximumBolusGuardrail: Guardrail<HKQuantity> {
        return Guardrail.maximumBolus(supportedBolusVolumes: supportedBolusVolumes)
    }

    var maximumBolusCard: Card {
        Card {
            SettingDescription(
                text: Text(DeliveryLimits.Setting.maximumBolus.descriptiveText), informationalContent: { TherapySetting.deliveryLimits.helpScreen() })
            ExpandableSetting(
                isEditing: Binding(
                    get: { self.settingBeingEdited == .maximumBolus },
                    set: { isEditing in
                        withAnimation {
                            self.settingBeingEdited = isEditing ? .maximumBolus : nil
                        }
                    }
                ),
                leadingValueContent: {
                    Text(DeliveryLimits.Setting.maximumBolus.title)
                },
                trailingValueContent: {
                    GuardrailConstrainedQuantityView(
                        value: value.maximumBolus,
                        unit: .internationalUnit(),
                        guardrail: maximumBolusGuardrail,
                        isEditing: settingBeingEdited == .maximumBolus,
                        forceDisableAnimations: true
                    )
                },
                expandedContent: {
                    FractionalQuantityPicker(
                        value: Binding(
                            get: { self.value.maximumBolus ?? self.maximumBolusGuardrail.recommendedBounds.upperBound },
                            set: { newValue in
                                withAnimation {
                                    self.value.maximumBolus = newValue
                                }
                            }
                        ),
                        unit: .internationalUnit(),
                        guardrail: self.maximumBolusGuardrail,
                        selectableValues: self.supportedBolusVolumes,
                        usageContext: .independent
                    )
                    .accessibility(identifier: "max_bolus_picker")
                }
            )
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

    private var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.crossedThresholds
        return Group {
            if !crossedThresholds.isEmpty && (userDidTap || mode == .settings || mode == .legacySettings) {
                DeliveryLimitsGuardrailWarning(crossedThresholds: crossedThresholds, maximumScheduledBasalRate: scheduledBasalRange?.upperBound)
            }
        }
    }

    private var crossedThresholds: [DeliveryLimits.Setting: SafetyClassification.Threshold] {
        var crossedThresholds: [DeliveryLimits.Setting: SafetyClassification.Threshold] = [:]

        switch value.maximumBasalRate.map(maximumBasalRateGuardrail.classification(for:)) {
        case nil, .withinRecommendedRange:
            break
        case .outsideRecommendedRange(let threshold):
            crossedThresholds[.maximumBasalRate] = threshold
        }

        switch value.maximumBolus.map(maximumBolusGuardrail.classification(for:)) {
        case nil, .withinRecommendedRange:
            break
        case .outsideRecommendedRange(let threshold):
            crossedThresholds[.maximumBolus] = threshold
        }

        return crossedThresholds
    }

    private func confirmationAlert() -> SwiftUI.Alert {
        SwiftUI.Alert(
            title: Text("Save Delivery Limits?", comment: "Alert title for confirming delivery limits outside the recommended range"),
            message: Text("One or more of the values you have entered are outside of what Tidepool generally recommends.", comment: "Alert message for confirming delivery limits outside the recommended range"),
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
        authenticate(TherapySetting.deliveryLimits.authenticationChallengeDescription) {
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
}


struct DeliveryLimitsGuardrailWarning: View {
    var crossedThresholds: [DeliveryLimits.Setting: SafetyClassification.Threshold]
    var maximumScheduledBasalRate: Double?

    private static let scheduledBasalRateMultiplierFormatter = NumberFormatter()

    private static let basalRateFormatter: NumberFormatter = {
        let formatter = QuantityFormatter()
        formatter.setPreferredNumberFormatter(for: .internationalUnitsPerHour)
        return formatter.numberFormatter
    }()

    var body: some View {
        switch crossedThresholds.count {
        case 0:
            preconditionFailure("A guardrail warning requires at least one crossed threshold")
        case 1:
            let (setting, threshold) = crossedThresholds.first!
            let title: Text, caption: Text?
            switch setting {
            case .maximumBasalRate:
                switch threshold {
                case .minimum, .belowRecommended:
                    title = Text("Low Maximum Basal Rate", comment: "Title text for low maximum basal rate warning")
                    caption = Text("A setting of 0 U/hr means Tidepool Loop will not automatically administer insulin.", comment: "Caption text for low maximum basal rate warning")
                case .aboveRecommended, .maximum:
                    guard let maximumScheduledBasalRate = maximumScheduledBasalRate else {
                        preconditionFailure("No maximum basal rate warning can be generated without a maximum scheduled basal rate")
                    }

                    title = Text("High Maximum Basal Rate", comment: "Title text for high maximum basal rate warning")
                    let scheduledBasalRateMultiplierString = Self.scheduledBasalRateMultiplierFormatter.string(from: Guardrail.recommendedMaximumScheduledBasalScaleFactor) ?? String(describing:  Guardrail.recommendedMaximumScheduledBasalScaleFactor)
                    let maximumScheduledBasalRateString = Self.basalRateFormatter.string(from: maximumScheduledBasalRate) ?? String(describing: maximumScheduledBasalRate)
                    caption = Text("The value you have entered exceeds \(scheduledBasalRateMultiplierString) times your highest scheduled basal rate of \(maximumScheduledBasalRateString) U/hr, which is higher than Tidepool generally recommends.", comment: "Caption text for high maximum basal rate warning")
                }
            case .maximumBolus:
                switch threshold {
                case .minimum, .belowRecommended:
                    title = Text("Low Maximum Bolus", comment: "Title text for low maximum bolus warning")
                    caption = Text("A setting of 0 U means you will not be able to bolus.", comment: "Caption text for zero maximum bolus setting warning")
                case .aboveRecommended, .maximum:
                    title = Text("High Maximum Bolus", comment: "Title text for high maximum bolus warning")
                    caption = nil
                }
            }

            return GuardrailWarning(title: title, threshold: threshold, caption: caption)
        case 2:
            return GuardrailWarning(
                title: Text("Delivery Limits"),
                thresholds: Array(crossedThresholds.values),
                caption: Text("The values you have entered are outside of what Tidepool generally recommends.", comment: "Caption text for warning where both delivery limits are outside the recommended range")
            )
        default:
            preconditionFailure("Unreachable: only two delivery limit settings exist")
        }
    }
}
