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

public typealias SyncDeliveryLimits = (_ deliveryLimits: DeliveryLimits, _ completion: @escaping (Swift.Result<DeliveryLimits, Error>) -> Void) -> Void

public struct DeliveryLimitsEditor: View {
    fileprivate enum PresentedAlert: Error {
        case saveConfirmation(AlertContent)
        case saveError(Error)
    }

    let initialValue: DeliveryLimits
    let supportedBasalRates: [Double]
    let selectableMaximumBasalRates: [Double]
    let scheduledBasalRange: ClosedRange<Double>?
    let supportedMaximumBolusVolumes: [Double]
    let selectableMaximumBolusVolumes: [Double]
    let syncDeliveryLimits: SyncDeliveryLimits?
    let save: (_ deliveryLimits: DeliveryLimits) -> Void
    let mode: SettingsPresentationMode

    @State var value: DeliveryLimits
    @State private var userDidTap: Bool = false
    @State var settingBeingEdited: DeliveryLimits.Setting?
    @State private var isSyncing = false
    @State private var presentedAlert: PresentedAlert?

    @Environment(\.dismissAction) var dismiss
    @Environment(\.authenticate) var authenticate
    @Environment(\.appName) var appName

    private let lowestCarbRatio: Double?

    public init(
        value: DeliveryLimits,
        supportedBasalRates: [Double],
        scheduledBasalRange: ClosedRange<Double>?,
        supportedMaximumBolusVolumes: [Double],
        lowestCarbRatio: Double?,
        syncDeliveryLimits: @escaping SyncDeliveryLimits,
        onSave save: @escaping (_ deliveryLimits: DeliveryLimits) -> Void,
        mode: SettingsPresentationMode = .settings
    ) {
        self._value = State(initialValue: value)
        self.initialValue = value
        self.supportedBasalRates = supportedBasalRates
        self.selectableMaximumBasalRates = Guardrail.selectableMaxBasalRates(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
        self.scheduledBasalRange = scheduledBasalRange
        self.supportedMaximumBolusVolumes = supportedMaximumBolusVolumes
        self.selectableMaximumBolusVolumes = Guardrail.selectableBolusVolumes(supportedBolusVolumes: supportedMaximumBolusVolumes)
        self.syncDeliveryLimits = syncDeliveryLimits
        self.save = save
        self.mode = mode
        self.lowestCarbRatio = lowestCarbRatio
    }
    
    public init(
        mode: SettingsPresentationMode,
        therapySettingsViewModel: TherapySettingsViewModel,
        didSave: (() -> Void)? = nil
    ) {
        precondition(therapySettingsViewModel.pumpSupportedIncrements() != nil)
        
        let maxBasal = therapySettingsViewModel.therapySettings.maximumBasalRatePerHour.map {
            HKQuantity(unit: .internationalUnitsPerHour, doubleValue: $0)
        }

        let maxBolus = therapySettingsViewModel.therapySettings.maximumBolus.map {
            HKQuantity(unit: .internationalUnit(), doubleValue: $0)
        }
        
        self.init(
            value: DeliveryLimits(maximumBasalRate: maxBasal, maximumBolus: maxBolus),
            supportedBasalRates: therapySettingsViewModel.pumpSupportedIncrements()?.basalRates ?? [],
            scheduledBasalRange: therapySettingsViewModel.therapySettings.basalRateSchedule?.valueRange(),
            supportedMaximumBolusVolumes: therapySettingsViewModel.pumpSupportedIncrements()?.maximumBolusVolumes ?? [],
            lowestCarbRatio: therapySettingsViewModel.therapySettings.carbRatioSchedule?.lowestValue(),
            syncDeliveryLimits: therapySettingsViewModel.syncDeliveryLimits,
            onSave: { [weak therapySettingsViewModel] newLimits in
                therapySettingsViewModel?.saveDeliveryLimits(limits: newLimits)
                didSave?()
            },
            mode: mode
        )
    }

    public var body: some View {
        switch mode {
        case .acceptanceFlow:
            content
                .disabled(isSyncing)
        case .settings:
            contentWithCancel
                .disabled(isSyncing)
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
    
    private var content: some View {
        ConfigurationPage(
            title: Text(TherapySetting.deliveryLimits.title),
            actionButtonTitle: Text(mode.buttonText(isSaving: isSyncing)),
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
                    self.presentedAlert = .saveConfirmation(confirmationAlertContent)
                }
            }
        )
        .alert(item: $presentedAlert, content: alert(for:))
        .simultaneousGesture(TapGesture().onEnded {
            withAnimation {
                self.userDidTap = true
            }
        })
    }

    var saveButtonState: ConfigurationPageActionButtonState {
        guard value.maximumBasalRate != nil, value.maximumBolus != nil else {
            return .disabled
        }

        if isSyncing {
            return .loading
        }
        
        if mode == .acceptanceFlow {
            return .enabled
        }

        return value == initialValue && mode != .acceptanceFlow ? .disabled : .enabled
    }

    var maximumBasalRateGuardrail: Guardrail<HKQuantity> {
        return Guardrail.maximumBasalRate(supportedBasalRates: supportedBasalRates, scheduledBasalRange: scheduledBasalRange, lowestCarbRatio: lowestCarbRatio)
    }

    var maximumBasalRateCard: Card {
        Card {
            SettingDescription(text: Text(DeliveryLimits.Setting.maximumBasalRate.localizedDescriptiveText(appName: appName)),
                               informationalContent: { TherapySetting.deliveryLimits.helpScreen() })
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
                            get: { self.value.maximumBasalRate ?? self.maximumBasalRateGuardrail.startingSuggestion ?? self.maximumBasalRateGuardrail.recommendedBounds.upperBound },
                            set: { newValue in
                                withAnimation {
                                    self.value.maximumBasalRate = newValue
                                }
                            }
                        ),
                        unit: .internationalUnitsPerHour,
                        guardrail: self.maximumBasalRateGuardrail,
                        selectableValues: self.selectableMaximumBasalRates,
                        usageContext: .independent
                    )
                    .accessibility(identifier: "max_basal_picker")
                }
            )
        }
    }

    var maximumBolusGuardrail: Guardrail<HKQuantity> {
        return Guardrail.maximumBolus(supportedBolusVolumes: supportedMaximumBolusVolumes)
    }

    var maximumBolusCard: Card {
        Card {
            SettingDescription(text: Text(DeliveryLimits.Setting.maximumBolus.localizedDescriptiveText(appName: appName)),
                               informationalContent: { TherapySetting.deliveryLimits.helpScreen() })
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
                            get: { self.value.maximumBolus ?? self.maximumBolusGuardrail.startingSuggestion ?? self.maximumBolusGuardrail.recommendedBounds.upperBound },
                            set: { newValue in
                                withAnimation {
                                    self.value.maximumBolus = newValue
                                }
                            }
                        ),
                        unit: .internationalUnit(),
                        guardrail: self.maximumBolusGuardrail,
                        selectableValues: self.selectableMaximumBolusVolumes,
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
            if !crossedThresholds.isEmpty && (userDidTap || mode == .settings) {
                DeliveryLimitsGuardrailWarning(crossedThresholds: crossedThresholds, value: value)
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

    private func startSaving() {
        guard mode == .settings else {
            self.monitorSavingMechanism(savingMechanism: .synchronous { deliveryLimits in
                save(deliveryLimits)
            })
            return
        }
        authenticate(TherapySetting.deliveryLimits.authenticationChallengeDescription) {
            switch $0 {
            case .success:
                self.monitorSavingMechanism(savingMechanism: .asynchronous { deliveryLimits, completion in
                    synchronizeDeliveryLimits(deliveryLimits, completion)
                })
            case .failure: break
            }
        }
    }

    private func synchronizeDeliveryLimits(_ deliveryLimits: DeliveryLimits, _ completion: @escaping (Error?) -> Void) {
        guard let syncDeliveryLimits = self.syncDeliveryLimits else {
            actuallySave(deliveryLimits)
            return
        }
        syncDeliveryLimits(deliveryLimits) { result in
            switch result {
            case .success(let deliveryLimits):
                actuallySave(deliveryLimits)
                completion(nil)
            case .failure(let error):
                completion(PresentedAlert.saveError(error))
            }
        }
    }
        
    private func actuallySave(_ deliveryLimits: DeliveryLimits) {
        DispatchQueue.main.async {
            self.save(deliveryLimits)
        }
    }
    
    private func monitorSavingMechanism(savingMechanism: SavingMechanism<DeliveryLimits>) {
        switch savingMechanism {
        case .synchronous(let save):
            save(value)
        case .asynchronous(let save):
            withAnimation {
                self.isSyncing = true
            }

            save(value) { error in
                DispatchQueue.main.async {
                    if let error = error  {
                        withAnimation {
                            self.isSyncing = false
                        }
                        self.presentedAlert = (error as? PresentedAlert) ?? .saveError(error)
                    }
                }
            }
        }
    }
    
    private func alert(for presentedAlert: PresentedAlert) -> SwiftUI.Alert {
        switch presentedAlert {
        case .saveConfirmation(let content):
            return SwiftUI.Alert(
                title: content.title,
                message: content.message,
                primaryButton: .cancel(
                    content.cancel ??
                    Text(LocalizedString("Go Back", comment: "Button text to return to editing a schedule after from alert popup when some schedule values are outside the recommended range"))),
                secondaryButton: .default(
                    content.ok ??
                    Text(LocalizedString("Continue", comment: "Button text to confirm saving from alert popup when some schedule values are outside the recommended range")),
                    action: startSaving
                )
            )
        case .saveError(let error):
            return SwiftUI.Alert(
                title: Text(LocalizedString("Unable to Save", comment: "Alert title when error occurs while saving a schedule")),
                message: Text(error.localizedDescription)
            )
        }
    }
    
    private var confirmationAlertContent: AlertContent {
        AlertContent(
            title: Text(LocalizedString("Save Delivery Limits?", comment: "Alert title for confirming delivery limits outside the recommended range")),
            message: Text(TherapySetting.deliveryLimits.guardrailSaveWarningCaption),
            cancel: Text(LocalizedString("Go Back", comment: "Text for go back action on confirmation alert")),
            ok: Text(LocalizedString("Continue", comment: "Text for continue action on confirmation alert")
            )
        )
    }
}


struct DeliveryLimitsGuardrailWarning: View {
    let crossedThresholds: [DeliveryLimits.Setting: SafetyClassification.Threshold]
    let value: DeliveryLimits
    var body: some View {
        switch crossedThresholds.count {
        case 0:
            preconditionFailure("A guardrail warning requires at least one crossed threshold")
        case 1:
            let (setting, threshold) = crossedThresholds.first!
            let title: Text
            switch setting {
            case .maximumBasalRate:
                switch threshold {
                case .minimum, .belowRecommended:
                    title = Text(LocalizedString("Low Maximum Basal Rate", comment: "Title text for low maximum basal rate warning"))
                case .aboveRecommended, .maximum:
                    title = Text(LocalizedString("High Maximum Basal Rate", comment: "Title text for high maximum basal rate warning"))
                }
            case .maximumBolus:
                switch threshold {
                case .minimum, .belowRecommended:
                    title = Text(LocalizedString("Low Maximum Bolus", comment: "Title text for low maximum bolus warning"))
                case .aboveRecommended, .maximum:
                    title = Text(LocalizedString("High Maximum Bolus", comment: "Title text for high maximum bolus warning"))
                }
            }

            return GuardrailWarning(therapySetting: .deliveryLimits, title: title, threshold: threshold)
        case 2:
            return GuardrailWarning(
                therapySetting: .deliveryLimits,
                title: Text(LocalizedString("Delivery Limits", comment: "Title text for crossed thresholds guardrail warning")),
                thresholds: Array(crossedThresholds.values))
        default:
            preconditionFailure("Unreachable: only two delivery limit settings exist")
        }
    }
}

extension DeliveryLimitsEditor.PresentedAlert: Identifiable {
    var id: Int {
        switch self {
        case .saveConfirmation:
            return 0
        case .saveError:
            return 1
        }
    }
}
