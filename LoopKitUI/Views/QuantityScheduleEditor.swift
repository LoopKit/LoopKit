//
//  QuantityScheduleEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/24/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


struct QuantityScheduleEditor<ActionAreaContent: View>: View {
    enum QuantitySelectionMode {
        /// A single picker for selecting quantity values.
        case whole
        // A two-component picker for selecting the whole and fractional quantity values independently.
        case fractional
    }

    var title: Text
    var description: Text
    var initialScheduleItems: [RepeatingScheduleValue<Double>]
    @State var scheduleItems: [RepeatingScheduleValue<Double>]
    var unit: HKUnit
    var selectableValues: [Double]
    var quantitySelectionMode: QuantitySelectionMode
    var guardrail: Guardrail<HKQuantity>
    var defaultFirstScheduleItemValue: HKQuantity
    var scheduleItemLimit: Int
    var confirmationAlertContent: AlertContent
    var guardrailWarning: (_ crossedThresholds: [SafetyClassification.Threshold]) -> ActionAreaContent
    var savingMechanism: SavingMechanism<DailyQuantitySchedule<Double>>
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ScheduleEditor(
            title: title,
            description: description,
            scheduleItems: $scheduleItems,
            initialScheduleItems: initialScheduleItems,
            defaultFirstScheduleItemValue: defaultFirstScheduleItemValue.doubleValue(for: unit),
            scheduleItemLimit: scheduleItemLimit,
            saveConfirmation: saveConfirmation,
            valueContent: { value, isEditing in
                GuardrailConstrainedQuantityView(
                    value: HKQuantity(unit: self.unit, doubleValue: value),
                    unit: self.unit,
                    guardrail: self.guardrail,
                    isEditing: isEditing
                )
            },
            valuePicker: { item, availableWidth in
                if self.quantitySelectionMode == .whole {
                    QuantityPicker(
                        value: item.value.animation().withUnit(self.unit),
                        unit: self.unit,
                        guardrail: self.guardrail,
                        selectableValues: self.selectableValues
                    )
                    .frame(width: availableWidth / 2)
                    // Ensure overlaid unit label is not clipped
                    .padding(.trailing, self.unitLabelWidth + self.unitLabelSpacing)
                    .clipped()
                } else {
                    FractionalQuantityPicker(
                        value: item.value.animation().withUnit(self.unit),
                        unit: self.unit,
                        guardrail: self.guardrail,
                        selectableValues: self.selectableValues,
                        usageContext: .component(availableWidth: availableWidth)
                    )
                }
            },
            actionAreaContent: {
                guardrailWarningIfNecessary
            },
            savingMechanism: savingMechanism.pullback { items in
                DailyQuantitySchedule(unit: self.unit, dailyItems: items)!
            }
        )
    }

    private var saveConfirmation: SaveConfirmation {
        crossedThresholds.isEmpty ? .notRequired : .required(confirmationAlertContent)
    }

    private var unitLabelWidth: CGFloat {
        let attributedUnitString = NSAttributedString(
            string: unit.shortLocalizedUnitString(),
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )
        return attributedUnitString.size().width
    }

    private var unitLabelSpacing: CGFloat { 8 }

    private var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.crossedThresholds
        return Group {
            if !crossedThresholds.isEmpty {
                guardrailWarning(crossedThresholds)
            }
        }
    }

    private var crossedThresholds: [SafetyClassification.Threshold] {
        scheduleItems.lazy
            .map { HKQuantity(unit: self.unit, doubleValue: $0.value) }
            .compactMap { quantity in
                switch guardrail.classification(for: quantity) {
                case .withinRecommendedRange:
                    return nil
                case .outsideRecommendedRange(let threshold):
                    return threshold
                }
        }
    }
}

// MARK: - Initializers

extension QuantityScheduleEditor {
    init(
        title: Text,
        description: Text,
        schedule: DailyQuantitySchedule<Double>?,
        unit: HKUnit,
        selectableValues: [Double],
        guardrail: Guardrail<HKQuantity>,
        quantitySelectionMode: QuantitySelectionMode = .whole,
        defaultFirstScheduleItemValue: HKQuantity,
        scheduleItemLimit: Int = 48,
        confirmationAlertContent: AlertContent,
        @ViewBuilder guardrailWarning: @escaping (_ thresholds: [SafetyClassification.Threshold]) -> ActionAreaContent,
        onSave savingMechanism: SavingMechanism<DailyQuantitySchedule<Double>>
    ) {
        self.title = title
        self.description = description
        self.initialScheduleItems = schedule?.items ?? []
        self._scheduleItems = State(initialValue: schedule?.items ?? [])
        self.unit = unit
        self.quantitySelectionMode = quantitySelectionMode
        self.selectableValues = selectableValues
        self.guardrail = guardrail
        self.defaultFirstScheduleItemValue = defaultFirstScheduleItemValue
        self.scheduleItemLimit = scheduleItemLimit
        self.confirmationAlertContent = confirmationAlertContent
        self.guardrailWarning = guardrailWarning
        self.savingMechanism = savingMechanism
    }

    init(
        title: Text,
        description: Text,
        schedule: DailyQuantitySchedule<Double>?,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        selectableValueStride: HKQuantity,
        quantitySelectionMode: QuantitySelectionMode = .whole,
        defaultFirstScheduleItemValue: HKQuantity,
        scheduleItemLimit: Int = 48,
        confirmationAlertContent: AlertContent,
        @ViewBuilder guardrailWarning: @escaping (_ thresholds: [SafetyClassification.Threshold]) -> ActionAreaContent,
        onSave save: @escaping (DailyQuantitySchedule<Double>) -> Void
    ) {
        let selectableValues = guardrail.allValues(stridingBy: selectableValueStride, unit: unit)
        self.init(
            title: title,
            description: description,
            schedule: schedule,
            unit: unit,
            selectableValues: selectableValues,
            guardrail: guardrail,
            quantitySelectionMode: quantitySelectionMode,
            defaultFirstScheduleItemValue: defaultFirstScheduleItemValue,
            scheduleItemLimit: scheduleItemLimit,
            confirmationAlertContent: confirmationAlertContent,
            guardrailWarning: guardrailWarning,
            onSave: .synchronous(save)
        )
    }
}
