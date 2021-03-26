//
//  InsulinSensitivityScheduleEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/20/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


public struct InsulinSensitivityScheduleEditor: View {
    @EnvironmentObject private var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable
    @Environment(\.appName) private var appName

    let viewModel: InsulinSensitivityScheduleEditorViewModel

    var displayGlucoseUnit: HKUnit {
        displayGlucoseUnitObservable.displayGlucoseUnit
    }

    public init(
        therapySettingsViewModel: TherapySettingsViewModel,
        didSave: (() -> Void)? = nil
    ) {
        self.viewModel = InsulinSensitivityScheduleEditorViewModel(
            therapySettingsViewModel: therapySettingsViewModel,
            didSave: didSave)
    }

    public var body: some View {
        QuantityScheduleEditor(
            title: Text(TherapySetting.insulinSensitivity.title),
            description: description,
            schedule: viewModel.insulinSensitivitySchedule?.schedule(for: displayGlucoseUnit),
            unit: sensitivityUnit,
            guardrail: .insulinSensitivity,
            selectableValueStride: stride,
            defaultFirstScheduleItemValue: Guardrail.insulinSensitivity.startingSuggestion ?? Guardrail.insulinSensitivity.recommendedBounds.upperBound,
            confirmationAlertContent: confirmationAlertContent,
            guardrailWarning: InsulinSensitivityGuardrailWarning.init(crossedThresholds:),
            onSave: { insulinSensitivitySchedulePerU in
                // the sensitivity units are passed as the units to display `/U`
                // need to go back to displayGlucoseUnit. This does not affect the value
                // force unwrapping since dailyItems are already validated
                let insulinSensitivitySchedule = InsulinSensitivitySchedule(unit: displayGlucoseUnit,
                                                                            dailyItems: insulinSensitivitySchedulePerU.items,
                                                                            timeZone: insulinSensitivitySchedulePerU.timeZone)!
                viewModel.saveInsulinSensitivitySchedule(insulinSensitivitySchedule)
            },
            mode: viewModel.mode,
            settingType: .insulinSensitivity
        )
    }

    private var description: Text {
        Text(TherapySetting.insulinSensitivity.descriptiveText(appName: appName))
    }

    private var sensitivityUnit: HKUnit {
        displayGlucoseUnit.unitDivided(by: .internationalUnit())
    }

    private var stride: HKQuantity {
        let doubleValue: Double
        switch displayGlucoseUnit {
        case .milligramsPerDeciliter:
            doubleValue = 1
        case .millimolesPerLiter:
            doubleValue = 0.1
        case let otherUnit:
            fatalError("Unsupported glucose unit \(otherUnit)")
        }

        return HKQuantity(unit: sensitivityUnit, doubleValue: doubleValue)
    }

    private var confirmationAlertContent: AlertContent {
        AlertContent(
            title: Text(LocalizedString("Save Insulin Sensitivities?", comment: "Alert title for confirming insulin sensitivities outside the recommended range")),
            message: Text(TherapySetting.insulinSensitivity.guardrailSaveWarningCaption)
        )
    }
}

private struct InsulinSensitivityGuardrailWarning: View {
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
            return Text(LocalizedString("Low Insulin Sensitivity", comment: "Title text for the low insulin sensitivity warning"))
        case .aboveRecommended, .maximum:
            return Text(LocalizedString("High Insulin Sensitivity", comment: "Title text for the high insulin sensitivity warning"))
        }
    }

    private var multipleWarningTitle: Text {
        Text(LocalizedString("Insulin Sensitivities", comment: "Title text for multi-value insulin sensitivity warning"))
    }
}
