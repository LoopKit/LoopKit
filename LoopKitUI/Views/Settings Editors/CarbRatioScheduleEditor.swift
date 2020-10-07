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
    private var mode: PresentationMode
    private var save: (CarbRatioSchedule) -> Void

    public init(
        schedule: CarbRatioSchedule?,
        onSave save: @escaping (CarbRatioSchedule) -> Void,
        mode: PresentationMode = .settings
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
        viewModel: TherapySettingsViewModel,
        didSave: (() -> Void)? = nil
    ) {
        self.init(
            schedule: viewModel.therapySettings.carbRatioSchedule,
            onSave: { [weak viewModel] in
                viewModel?.saveCarbRatioSchedule(carbRatioSchedule: $0)
                didSave?()
            },
            mode: viewModel.mode
        )
    }

    public var body: some View  {
        QuantityScheduleEditor(
            title: Text(TherapySetting.carbRatio.title),
            description: description,
            schedule: schedule,
            unit: .realCarbRatioScheduleUnit,
            guardrail: .carbRatio,
            selectableValueStride: HKQuantity(unit: .realCarbRatioScheduleUnit, doubleValue: 0.01),
            quantitySelectionMode: .fractional,
            defaultFirstScheduleItemValue: Guardrail.carbRatio.startingSuggestion ?? Guardrail.carbRatio.absoluteBounds.upperBound,
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
        Text(TherapySetting.carbRatio.descriptiveText)
    }

    private var confirmationAlertContent: AlertContent {
        AlertContent(
            title: Text("Save Carb Ratios?", comment: "Alert title for confirming carb ratios outside the recommended range"),
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
            return Text("Low Carb Ratio", comment: "Title text for the low carb ratio warning")
        case .aboveRecommended, .maximum:
            return Text("High Carb Ratio", comment: "Title text for the high carb ratio warning")
        }
    }

    private var multipleWarningTitle: Text {
        Text("Carb Ratios", comment: "Title text for multi-value carb ratio warning")
    }
}
