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
    private var schedule: DailyQuantitySchedule<Double>?
    private var glucoseUnit: HKUnit
    private var save: (InsulinSensitivitySchedule) -> Void
    private var mode: PresentationMode

    public init(
        schedule: InsulinSensitivitySchedule?,
        mode: PresentationMode = .legacySettings,
        glucoseUnit: HKUnit,
        onSave save: @escaping (InsulinSensitivitySchedule) -> Void
    ) {
        // InsulinSensitivitySchedule stores only the glucose unit.
        // For consistency across display & computation, convert to "real" <glucose unit>/U units.
        self.schedule = schedule.map { schedule in
            DailyQuantitySchedule(
                unit: glucoseUnit.unitDivided(by: .internationalUnit()),
                dailyItems: schedule.items
            )!
        }
        self.glucoseUnit = glucoseUnit
        self.save = save
        self.mode = mode
    }

    public var body: some View {
        QuantityScheduleEditor(
            title: Text(TherapySetting.insulinSensitivity.title),
            description: description,
            schedule: schedule,
            unit: sensitivityUnit,
            guardrail: .insulinSensitivity,
            selectableValueStride: stride,
            defaultFirstScheduleItemValue: Guardrail.insulinSensitivity.absoluteBounds.upperBound,
            confirmationAlertContent: confirmationAlertContent,
            guardrailWarning: InsulinSensitivityGuardrailWarning.init(crossedThresholds:),
            onSave: {
                // Convert back to the expected glucose-unit-only schedule.
                self.save(DailyQuantitySchedule(unit: self.glucoseUnit, dailyItems: $0.items)!)
            },
            mode: mode,
            settingType: .insulinSensitivity
        )
    }

    private var description: Text {
        Text(TherapySetting.insulinSensitivity.descriptiveText)
    }

    private var sensitivityUnit: HKUnit {
         glucoseUnit.unitDivided(by: .internationalUnit())
    }

    private var stride: HKQuantity {
        let doubleValue: Double
        switch glucoseUnit {
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
            title: Text("Save Insulin Sensitivities?", comment: "Alert title for confirming insulin sensitivities outside the recommended range"),
            message: Text("One or more of the values you have entered are outside of what Tidepool generally recommends.", comment: "Alert message for confirming insulin sensitivities outside the recommended range")
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
            return Text("Low Insulin Sensitivity", comment: "Title text for the low insulin sensitivity warning")
        case .aboveRecommended, .maximum:
            return Text("High Insulin Sensitivity", comment: "Title text for the high insulin sensitivity warning")
        }
    }

    private var multipleWarningTitle: Text {
        Text("Insulin Sensitivities", comment: "Title text for multi-value insulin sensitivity warning")
    }
}
