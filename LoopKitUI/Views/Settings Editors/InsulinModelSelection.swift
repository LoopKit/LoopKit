//
//  InsulinModelSelection.swift
//  Loop
//
//  Created by Michael Pangburn on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public struct InsulinModelSelection: View {
    @EnvironmentObject private var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable
    @Environment(\.appName) private var appName   
    @Environment(\.dismissAction) private var dismiss
    @Environment(\.authenticate) private var authenticate

    @State private var value: InsulinModelSettings
    @State private var chartManager: ChartsManager

    private let initialValue: InsulinModelSettings
    private let insulinSensitivitySchedule: InsulinSensitivitySchedule
    private let supportedInsulinModelSettings: SupportedInsulinModelSettings
    private let mode: SettingsPresentationMode
    private let save: (_ insulinModelSettings: InsulinModelSettings) -> Void

    static let defaultInsulinSensitivitySchedule = InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue<Double>(startTime: 0, value: 40)])!
    
    static let defaultWalshInsulinModelDuration = TimeInterval(hours: 6)

    var walshActionDuration: Binding<TimeInterval> {
        Binding(
            get: {
                if case .walsh(let walshModel) = value {
                    return walshModel.actionDuration
                } else {
                    return Self.defaultWalshInsulinModelDuration
                }
            },
            set: { newValue in
                precondition(InsulinModelSettings.validWalshModelDurationRange.contains(newValue))
                value = .walsh(WalshInsulinModel(actionDuration: newValue))
            }
        )
    }

    private var displayGlucoseUnit: HKUnit {
        displayGlucoseUnitObservable.displayGlucoseUnit
    }

    public init(
        value: InsulinModelSettings,
        insulinSensitivitySchedule: InsulinSensitivitySchedule?,
        supportedInsulinModelSettings: SupportedInsulinModelSettings,
        chartColors: ChartColorPalette,
        onSave save: @escaping (_ insulinModelSettings: InsulinModelSettings) -> Void,
        mode: SettingsPresentationMode
    ){
        self._value = State(initialValue: value)
        self.initialValue = value
        self.insulinSensitivitySchedule = insulinSensitivitySchedule ?? Self.defaultInsulinSensitivitySchedule
        self.save = save
        self.supportedInsulinModelSettings = supportedInsulinModelSettings
        self.mode = mode

        let chartManager = ChartsManager(
            colors: chartColors,
            settings: .default,
            axisLabelFont: .systemFont(ofSize: 12),
            charts: [InsulinModelChart()],
            traitCollection: .current
        )

        chartManager.startDate = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(minute: 0),
            matchingPolicy: .strict,
            direction: .backward
        ) ?? Date()
        self._chartManager = State(initialValue: chartManager)
    }

    public init(
        mode: SettingsPresentationMode,
        therapySettingsViewModel: TherapySettingsViewModel,
        chartColors: ChartColorPalette,
        didSave: (() -> Void)? = nil
    ) {
        self.init(
            value: therapySettingsViewModel.therapySettings.insulinModelSettings ?? InsulinModelSettings.exponentialPreset(.humalogNovologAdult),
            insulinSensitivitySchedule: therapySettingsViewModel.therapySettings.insulinSensitivitySchedule,
            supportedInsulinModelSettings: therapySettingsViewModel.supportedInsulinModelSettings,
            chartColors: chartColors,
            onSave: { [weak therapySettingsViewModel] insulinModelSettings in
                therapySettingsViewModel?.saveInsulinModel(insulinModelSettings: insulinModelSettings)
                didSave?()
            },
            mode: mode
        )
    }

    public var body: some View {
        switch mode {
        case .acceptanceFlow:
            content
        case .settings:
            contentWithCancel
                .navigationBarTitleDisplayMode(.inline)
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
        Button(action: { dismiss() } ) { Text(LocalizedString("Cancel", comment: "Cancel editing settings button title")) }
    }
    
    private var content: some View {
        VStack(spacing: 0) {
            CardList(title: Text(LocalizedString("Insulin Model", comment: "Title text for insulin model")),
                     style: .simple(CardStack(cards: [card])))
            Button(action: { startSaving() }) {
                Text(mode.buttonText)
                    .actionButtonStyle(.primary)
                    .padding()
            }
            .disabled(value == initialValue && mode != .acceptanceFlow)
            // Styling to mimic the floating button of a ConfigurationPage
            .padding(.bottom)
            .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
        }
        .supportedInterfaceOrientations(.portrait)
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private var card: Card {
        Card {
            Section {
                SettingDescription(
                    text: insulinModelSettingDescription,
                    informationalContent: {
                        TherapySetting.insulinModel.helpScreen()
                    }
                )
                .padding(4)
                .padding(.top, 4)

                VStack {
                    InsulinModelChartView(
                        chartManager: chartManager,
                        glucoseUnit: displayGlucoseUnit,
                        selectedInsulinModelValues: selectedInsulinModelValues,
                        unselectedInsulinModelValues: unselectedInsulinModelValues,
                        glucoseDisplayRange: endingGlucoseQuantity...startingGlucoseQuantity
                    )
                    .frame(height: 170)

                    CheckmarkListItem(
                        title: Text(InsulinModelSettings.exponentialPreset(.humalogNovologAdult).title),
                        description: Text(InsulinModelSettings.exponentialPreset(.humalogNovologAdult).subtitle),
                        isSelected: isSelected(.exponentialPreset(.humalogNovologAdult))
                    )
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }

                SectionDivider()
                CheckmarkListItem(
                    title: Text(InsulinModelSettings.exponentialPreset(.humalogNovologChild).title),
                    description: Text(InsulinModelSettings.exponentialPreset(.humalogNovologChild).subtitle),
                    isSelected: isSelected(.exponentialPreset(.humalogNovologChild))
                )
                .padding(.vertical, 4)
                .padding(.bottom, supportedInsulinModelSettings.fiaspModelEnabled ? 0 : 4)
                .contentShape(Rectangle())

                if supportedInsulinModelSettings.fiaspModelEnabled {
                    SectionDivider()
                    CheckmarkListItem(
                        title: Text(InsulinModelSettings.exponentialPreset(.fiasp).title),
                        description: Text(InsulinModelSettings.exponentialPreset(.fiasp).subtitle),
                        isSelected: isSelected(.exponentialPreset(.fiasp))
                    )
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }

                if supportedInsulinModelSettings.walshModelEnabled {
                    SectionDivider()
                    DurationBasedCheckmarkListItem(
                        title: Text(WalshInsulinModel.title),
                        description: Text(WalshInsulinModel.subtitle),
                        isSelected: isWalshModelSelected,
                        duration: walshActionDuration,
                        validDurationRange: InsulinModelSettings.validWalshModelDurationRange
                    )
                    .padding(.vertical, 4)
                    .padding(.bottom, 4)
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(PlainButtonStyle()) // Disable row highlighting on selection
        }
    }

    var insulinModelSettingDescription: Text {
        let spellOutFormatter = NumberFormatter()
        spellOutFormatter.numberStyle = .spellOut
        let modelCountString = spellOutFormatter.string(from: selectableInsulinModelSettings.count as NSNumber)!
        return Text(String(format: LocalizedString("%1$@ assumes insulin is actively working for 6 hours. You can choose from %2$@ different models for how the app measures the insulin’s peak activity.", comment: "Insulin model setting description (1: app name) (2: number of models)"), appName, modelCountString))
    }

    var selectableInsulinModelSettings: [InsulinModelSettings] {
        var options: [InsulinModelSettings] =  [
            .exponentialPreset(.humalogNovologAdult),
            .exponentialPreset(.humalogNovologChild)
        ]

        if supportedInsulinModelSettings.fiaspModelEnabled {
            options.append(.exponentialPreset(.fiasp))
        }

        if supportedInsulinModelSettings.walshModelEnabled {
            options.append(.walsh(WalshInsulinModel(actionDuration: walshActionDuration.wrappedValue)))
        }

        return options
    }

    private var selectedInsulinModelValues: [GlucoseValue] {
        oneUnitBolusEffectPrediction(using: value.model)
    }

    private var unselectedInsulinModelValues: [[GlucoseValue]] {
        selectableInsulinModelSettings
            .filter { $0 != value }
            .map { oneUnitBolusEffectPrediction(using: $0.model) }
    }

    private func oneUnitBolusEffectPrediction(using model: InsulinModel) -> [GlucoseValue] {
        let bolus = DoseEntry(type: .bolus, startDate: chartManager.startDate, value: 1, unit: .units)
        let startingGlucoseSample = HKQuantitySample(type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!, quantity: startingGlucoseQuantity, start: chartManager.startDate, end: chartManager.startDate)
        let effects = [bolus].glucoseEffects(insulinModel: model, insulinSensitivity: insulinSensitivitySchedule)
        return LoopMath.predictGlucose(startingAt: startingGlucoseSample, effects: effects)
    }

    private var startingGlucoseQuantity: HKQuantity {
        let startingGlucoseValue = insulinSensitivitySchedule.quantity(at: chartManager.startDate).doubleValue(for: displayGlucoseUnit) + displayGlucoseUnit.glucoseExampleTargetValue
        return HKQuantity(unit: displayGlucoseUnit, doubleValue: startingGlucoseValue)
    }

    private var endingGlucoseQuantity: HKQuantity {
        HKQuantity(unit: displayGlucoseUnit, doubleValue: displayGlucoseUnit.glucoseExampleTargetValue)
    }

    private func isSelected(_ settings: InsulinModelSettings) -> Binding<Bool> {
        Binding(
            get: { value == settings },
            set: { isSelected in
                if isSelected {
                    withAnimation {
                        value = settings
                    }
                }
            }
        )
    }

    private var isWalshModelSelected: Binding<Bool> {
        Binding(
            get: { value.model is WalshInsulinModel },
            set: { isSelected in
                if isSelected {
                    withAnimation {
                        value = .walsh(WalshInsulinModel(actionDuration: walshActionDuration.wrappedValue))
                    }
                }
            }
        )
    }
    
    private func startSaving() {
        guard mode == .settings else {
            continueSaving()
            return
        }
        authenticate(TherapySetting.insulinModel.authenticationChallengeDescription) {
            switch $0 {
            case .success: continueSaving()
            case .failure: break
            }
        }
    }
    
    private func continueSaving() {
        save(value)
    }

    var dismissButton: some View {
        Button(action: dismiss) {
            Text(LocalizedString("Close", comment: "Button text to close a modal"))
        }
    }
}

fileprivate extension HKUnit {
    /// An example value for the "ideal" target
    var glucoseExampleTargetValue: Double {
        if self == .milligramsPerDeciliter {
            return 100
        } else {
            return 5.5
        }
    }
}

fileprivate struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.trailing, -16)
    }
}
