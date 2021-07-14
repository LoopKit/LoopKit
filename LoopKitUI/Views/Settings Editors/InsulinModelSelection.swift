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
            value: therapySettingsViewModel.therapySettings.insulinModelSettings ?? InsulinModelSettings.exponentialPreset(.rapidActingAdult),
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
                        title: Text(InsulinModelSettings.exponentialPreset(.rapidActingAdult).title),
                        description: Text(InsulinModelSettings.exponentialPreset(.rapidActingAdult).subtitle),
                        isSelected: isSelected(.exponentialPreset(.rapidActingAdult))
                    )
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }

                SectionDivider()
                CheckmarkListItem(
                    title: Text(InsulinModelSettings.exponentialPreset(.rapidActingChild).title),
                    description: Text(InsulinModelSettings.exponentialPreset(.rapidActingChild).subtitle),
                    isSelected: isSelected(.exponentialPreset(.rapidActingChild))
                )
                .padding(.vertical, 4)
                .padding(.bottom, 4)
            }
            .buttonStyle(PlainButtonStyle()) // Disable row highlighting on selection
        }
    }

    var insulinModelSettingDescription: Text {
        let spellOutFormatter = NumberFormatter()
        spellOutFormatter.numberStyle = .spellOut
        let modelCountString = spellOutFormatter.string(from: selectableInsulinModelSettings.count as NSNumber)!
        return Text(String(format: LocalizedString("For fast acting insulin, %1$@ assumes it is actively working for 6 hours. You can choose from %2$@ different models for how the app measures the insulin’s peak activity.", comment: "Insulin model setting description (1: app name) (2: number of models)"), appName, modelCountString))
    }

    var selectableInsulinModelSettings: [InsulinModelSettings] {
        var options: [InsulinModelSettings] =  [
            .exponentialPreset(.rapidActingAdult),
            .exponentialPreset(.rapidActingChild)
        ]

        return options
    }

    private var selectedInsulinModelValues: [GlucoseValue] {
        oneUnitBolusEffectPrediction(using: value)
    }

    private var unselectedInsulinModelValues: [[GlucoseValue]] {
        selectableInsulinModelSettings
            .filter { $0 != value }
            .map { oneUnitBolusEffectPrediction(using: $0) }
    }

    private func oneUnitBolusEffectPrediction(using modelSettings: InsulinModelSettings) -> [GlucoseValue] {
        let bolus = DoseEntry(type: .bolus, startDate: chartManager.startDate, value: 1, unit: .units, insulinType: .novolog)
        let startingGlucoseSample = HKQuantitySample(type: HKQuantityType.quantityType(forIdentifier: .bloodGlucose)!, quantity: startingGlucoseQuantity, start: chartManager.startDate, end: chartManager.startDate)
        let effects = [bolus].glucoseEffects(insulinModelSettings: modelSettings, insulinSensitivity: insulinSensitivitySchedule)
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
