//
//  CarbRatioScheduleEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/20/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


fileprivate extension HKUnit {
    static let storedCarbRatioScheduleUnit = HKUnit.gram()
    static let realCarbRatioScheduleUnit = HKUnit.gramsPerUnit
}

public struct CarbRatioScheduleEditor: View {
    private var schedule: DailyQuantitySchedule<Double>?
    private var mode: SettingsPresentationMode
    private var save: (CarbRatioSchedule) -> Void
    @Environment(\.appName) private var appName

    public init(
        schedule: CarbRatioSchedule?,
        onSave save: @escaping (CarbRatioSchedule) -> Void,
        mode: SettingsPresentationMode = .settings
    ) {
        // CarbRatioSchedule stores only the gram unit.
        // For consistency across display & computation, convert to "real" g/U units.
        self.schedule = schedule.map { schedule in
            DailyQuantitySchedule(
                unit: .realCarbRatioScheduleUnit,
                dailyItems: schedule.items
            )!
        }
        self.mode = mode
        self.save = save
    }
    
    public init(
        mode: SettingsPresentationMode,
        therapySettingsViewModel: TherapySettingsViewModel,
        didSave: (() -> Void)? = nil
    ) {
        self.init(
            schedule: therapySettingsViewModel.therapySettings.carbRatioSchedule,
            onSave: { [weak therapySettingsViewModel] in
                therapySettingsViewModel?.saveCarbRatioSchedule(carbRatioSchedule: $0)
                didSave?()
            },
            mode: mode
        )
    }

    public var body: some View  {
        QuantityScheduleEditor(
            title: Text(TherapySetting.carbRatio.title),
            description: description,
            schedule: schedule,
            unit: .realCarbRatioScheduleUnit,
            guardrail: .carbRatio,
            selectableValueStride: HKQuantity(unit: .realCarbRatioScheduleUnit, doubleValue: 0.1),
            quantitySelectionMode: .fractional,
            defaultFirstScheduleItemValue: Guardrail.carbRatio.startingSuggestion ?? Guardrail.carbRatio.recommendedBounds.upperBound,
            confirmationAlertContent: confirmationAlertContent,
            guardrailWarning: CarbRatioGuardrailWarning.init(crossedThresholds:),
            onSave: {
                // Convert back to the expected gram-unit-only schedule.
                self.save(DailyQuantitySchedule(unit: .storedCarbRatioScheduleUnit, dailyItems: $0.items)!)
            },
            mode: mode,
            settingType: .carbRatio
        )
    }

    private var description: Text {
        Text(TherapySetting.carbRatio.descriptiveText(appName: appName))
    }

    private var confirmationAlertContent: AlertContent {
        AlertContent(
            title: Text(LocalizedString("Save Carb Ratios?", comment: "Alert title for confirming carb ratios outside the recommended range")),
            message: Text(TherapySetting.carbRatio.guardrailSaveWarningCaption)
        )
    }
}

private struct CarbRatioGuardrailWarning: View {
    var crossedThresholds: [SafetyClassification.Threshold]

    var body: some View {
        assert(!crossedThresholds.isEmpty)
        return GuardrailWarning(
            title: crossedThresholds.count == 1 ? singularWarningTitle(for: crossedThresholds.first!) : multipleWarningTitle,
            thresholds: crossedThresholds
        )
    }

    private func singularWarningTitle(for threshold: SafetyClassification.Threshold) -> Text {
        switch threshold {
        case .minimum, .belowRecommended:
            return Text(LocalizedString("Low Carb Ratio", comment: "Title text for the low carb ratio warning"))
        case .aboveRecommended, .maximum:
            return Text(LocalizedString("High Carb Ratio", comment: "Title text for the high carb ratio warning"))
        }
    }

    private var multipleWarningTitle: Text {
        Text(LocalizedString("Carb Ratios", comment: "Title text for multi-value carb ratio warning"))
    }
}
