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
    static let realCarbRatioScheduleUnit = HKUnit.gram().unitDivided(by: .internationalUnit())
}

extension Guardrail where Value == HKQuantity {
    static let carbRatio = Guardrail(
        absoluteBounds: 1...150,
        recommendedBounds: 3.0.nextUp...28.0.nextDown,
        unit: .realCarbRatioScheduleUnit
    )
}

public struct CarbRatioScheduleEditor: View {
    private var schedule: DailyQuantitySchedule<Double>?
    private var save: (CarbRatioSchedule) -> Void

    public init(
        schedule: CarbRatioSchedule?,
        onSave save: @escaping (CarbRatioSchedule) -> Void
    ) {
        // CarbRatioSchedule stores only the gram unit.
        // For consistency across display & computation, convert to "real" g/U units.
        self.schedule = schedule.map { schedule in
            DailyQuantitySchedule(
                unit: .realCarbRatioScheduleUnit,
                dailyItems: schedule.items
            )!
        }
        self.save = save
    }

    public var body: some View {
        QuantityScheduleEditor(
            title: Text("Carb Ratios", comment: "Title of carb ratio settings page"),
            description: description,
            schedule: schedule,
            unit: .realCarbRatioScheduleUnit,
            guardrail: .carbRatio,
            selectableValueStride: HKQuantity(unit: .realCarbRatioScheduleUnit, doubleValue: 0.01),
            quantitySelectionMode: .fractional,
            defaultFirstScheduleItemValue: Guardrail.carbRatio.absoluteBounds.upperBound,
            confirmationAlertContent: confirmationAlertContent,
            guardrailWarning: CarbRatioGuardrailWarning.init(crossedThresholds:),
            onSave: {
                // Convert back to the expected gram-unit-only schedule.
                self.save(DailyQuantitySchedule(unit: .storedCarbRatioScheduleUnit, dailyItems: $0.items)!)
            }
        )
    }

    private var description: Text {
        Text("Your carb ratio is the number of grams of carbohydrate covered by one unit of insulin.", comment: "Carb ratio setting description")
    }

    private var confirmationAlertContent: AlertContent {
        AlertContent(
            title: Text("Save Carb Ratios?", comment: "Alert title for confirming carb ratios outside the recommended range"),
            message: Text("One or more of the values you have entered are outside of what Tidepool generally recommends.", comment: "Alert message for confirming carb ratios outside the recommended range")
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
