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

public struct InsulinModelSelection: View, HorizontalSizeClassOverride {
    @Environment(\.appName) private var appName   
    
    let initialValue: InsulinModelSettings
    @State var value: InsulinModelSettings
    let insulinSensitivitySchedule: InsulinSensitivitySchedule
    let glucoseUnit: HKUnit
    let supportedModelSettings: SupportedInsulinModelSettings
    let mode: PresentationMode
    let save: (InsulinModelSettings) -> Void

    static let defaultInsulinSensitivitySchedule = InsulinSensitivitySchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue<Double>(startTime: 0, value: 40)])!
    
    static let defaultWalshInsulinModelDuration = TimeInterval(hours: 6)

    var walshActionDuration: Binding<TimeInterval> {
        Binding(
            get: {
                if case .walsh(let walshModel) = self.value {
                    return walshModel.actionDuration
                } else {
                    return Self.defaultWalshInsulinModelDuration
                }
            },
            set: { newValue in
                precondition(InsulinModelSettings.validWalshModelDurationRange.contains(newValue))
                self.value = .walsh(WalshInsulinModel(actionDuration: newValue))
            }
        )
    }

    public init(
        value: InsulinModelSettings,
        insulinSensitivitySchedule: InsulinSensitivitySchedule?,
        glucoseUnit: HKUnit,
        supportedModelSettings: SupportedInsulinModelSettings,
        mode: PresentationMode,
        onSave save: @escaping (InsulinModelSettings) -> Void
    ){
        self._value = State(initialValue: value)
        self.initialValue = value
        self.insulinSensitivitySchedule = insulinSensitivitySchedule ?? Self.defaultInsulinSensitivitySchedule
        self.save = save
        self.glucoseUnit = glucoseUnit
        self.supportedModelSettings = supportedModelSettings
        self.mode = mode
    }

    let chartManager: ChartsManager = {
        let chartManager = ChartsManager(
            colors: .default,
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

        return chartManager
    }()

    @Environment(\.dismiss) var dismiss
    
    public var body: some View {
        switch mode {
        case .acceptanceFlow: return AnyView(contentWithSaveButton)
        case .settings:       return AnyView(contentWithSaveButton)
        case .legacySettings: return AnyView(navigationContent)
        }
    }
    
    private var navigationContent: some View {
        NavigationView {
            contentWithSaveButton
            .navigationBarItems(leading: dismissButton)
        }
    }
    
    private var contentWithSaveButton: some View {
        VStack {
            content
            Button(action: { self.doSave() }) {
                Text(mode.buttonText)
                    .actionButtonStyle(.primary)
                    .padding()
            }
            .disabled(value == initialValue && mode != .acceptanceFlow)
            // Styling to mimic the floating button of a ConfigurationPage
            .padding(.bottom)
            .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
        }
        .edgesIgnoringSafeArea(.bottom)
    }
    
    private var content: some View {
        List {
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
                        glucoseUnit: glucoseUnit,
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
                }

                CheckmarkListItem(
                    title: Text(InsulinModelSettings.exponentialPreset(.humalogNovologChild).title),
                    description: Text(InsulinModelSettings.exponentialPreset(.humalogNovologChild).subtitle),
                    isSelected: isSelected(.exponentialPreset(.humalogNovologChild))
                )
                .padding(.vertical, 4)
                .padding(.bottom, supportedModelSettings.fiaspModelEnabled ? 0 : 4)

                if supportedModelSettings.fiaspModelEnabled {
                    CheckmarkListItem(
                        title: Text(InsulinModelSettings.exponentialPreset(.fiasp).title),
                        description: Text(InsulinModelSettings.exponentialPreset(.fiasp).subtitle),
                        isSelected: isSelected(.exponentialPreset(.fiasp))
                    )
                    .padding(.vertical, 4)
                }

                if supportedModelSettings.walshModelEnabled {
                    DurationBasedCheckmarkListItem(
                        title: Text(WalshInsulinModel.title),
                        description: Text(WalshInsulinModel.subtitle),
                        isSelected: isWalshModelSelected,
                        duration: walshActionDuration,
                        validDurationRange: InsulinModelSettings.validWalshModelDurationRange
                    )
                    .padding(.vertical, 4)
                    .padding(.bottom, 4)
                }
            }
            .buttonStyle(PlainButtonStyle()) // Disable row highlighting on selection
        }
        .listStyle(GroupedListStyle())
        .environment(\.horizontalSizeClass, horizontalOverride)
        .navigationBarTitle(Text(TherapySetting.insulinModel.title), displayMode: .large)
    }

    var insulinModelSettingDescription: Text {
        let spellOutFormatter = NumberFormatter()
        spellOutFormatter.numberStyle = .spellOut
        return Text("\(appName) assumes insulin is actively working for 6 hours. You can choose from \(selectableInsulinModelSettings.count as NSNumber, formatter: spellOutFormatter) different models for how the app measures the insulin’s peak activity.", comment: "Insulin model setting description (1: app name) (2: number of models)")
    }

    var insulinModelChart: InsulinModelChart {
        chartManager.charts.first! as! InsulinModelChart
    }

    var selectableInsulinModelSettings: [InsulinModelSettings] {
        var options: [InsulinModelSettings] =  [
            .exponentialPreset(.humalogNovologAdult),
            .exponentialPreset(.humalogNovologChild)
        ]

        if supportedModelSettings.fiaspModelEnabled {
            options.append(.exponentialPreset(.fiasp))
        }

        if supportedModelSettings.walshModelEnabled {
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
        let startingGlucoseValue = insulinSensitivitySchedule.quantity(at: chartManager.startDate).doubleValue(for: glucoseUnit) + glucoseUnit.glucoseExampleTargetValue
        return HKQuantity(unit: glucoseUnit, doubleValue: startingGlucoseValue)
    }

    private var endingGlucoseQuantity: HKQuantity {
        HKQuantity(unit: glucoseUnit, doubleValue: glucoseUnit.glucoseExampleTargetValue)
    }

    private func isSelected(_ settings: InsulinModelSettings) -> Binding<Bool> {
        Binding(
            get: { self.value == settings },
            set: { isSelected in
                if isSelected {
                    withAnimation {
                        self.value = settings
                    }
                }
            }
        )
    }

    private var isWalshModelSelected: Binding<Bool> {
        Binding(
            get: { self.value.model is WalshInsulinModel },
            set: { isSelected in
                if isSelected {
                    withAnimation {
                        self.value = .walsh(WalshInsulinModel(actionDuration: self.walshActionDuration.wrappedValue))
                    }
                }
            }
        )
    }

    private func doSave() {
        save(value)
        if mode == .legacySettings {
            dismiss()
        }
    }
    
    var dismissButton: some View {
        Button(action: dismiss) {
            Text("Close", comment: "Button text to close a modal")
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
