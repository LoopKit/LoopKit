//
//  CorrectionRangeScheduleEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


public struct CorrectionRangeScheduleEditor: View {
    @EnvironmentObject private var displayGlucoseUnitObservable: DisplayGlucoseUnitObservable
    @Environment(\.appName) private var appName

    let viewModel: CorrectionRangeScheduleEditorViewModel

    @State var scheduleItems: [RepeatingScheduleValue<ClosedRange<HKQuantity>>]

    @State private var userDidTap: Bool = false

    var displayGlucoseUnit: HKUnit {
        displayGlucoseUnitObservable.displayGlucoseUnit
    }

    var initialSchedule: GlucoseRangeSchedule? {
        viewModel.glucoseTargetRangeSchedule
    }

    public init(
        therapySettingsViewModel: TherapySettingsViewModel,
        didSave: (() -> Void)? = nil
    ) {
        self._scheduleItems = State(initialValue: therapySettingsViewModel.glucoseTargetRangeSchedule?.quantityRanges ?? [])
        self.viewModel = CorrectionRangeScheduleEditorViewModel(
            therapySettingsViewModel: therapySettingsViewModel,
            didSave: didSave)
    }

    public var body: some View {
        ScheduleEditor(
            title: Text(TherapySetting.glucoseTargetRange.title),
            description: description,
            scheduleItems: $scheduleItems,
            initialScheduleItems: initialSchedule?.quantityRanges ?? [],
            defaultFirstScheduleItemValue: defaultFirstScheduleItemValue,
            saveConfirmation: saveConfirmation,
            valueContent: { range, isEditing in
                GuardrailConstrainedQuantityRangeView(
                    range: range,
                    unit: displayGlucoseUnit,
                    guardrail: viewModel.guardrail,
                    isEditing: isEditing)
            },
            valuePicker: { scheduleItem, availableWidth in
                GlucoseRangePicker(
                    range: Binding(
                        get: { scheduleItem.wrappedValue.value },
                        set: { quantityRange in
                            withAnimation {
                                scheduleItem.wrappedValue.value = quantityRange
                            }
                        }
                    ),
                    unit: displayGlucoseUnit,
                    minValue: viewModel.minValue,
                    guardrail: viewModel.guardrail,
                    usageContext: .component(availableWidth: availableWidth)
                )
            },
            actionAreaContent: {
                instructionalContentIfNecessary
                guardrailWarningIfNecessary
            },
            savingMechanism: .synchronous { dailyQuantities in
                let rangeSchedule = DailyQuantitySchedule(
                    unit: displayGlucoseUnit,
                    dailyQuantities: dailyQuantities,
                    timeZone: initialSchedule?.timeZone)!
                let glucoseTargetRangeSchedule = GlucoseRangeSchedule(
                    rangeSchedule: rangeSchedule,
                    override: initialSchedule?.override)
                viewModel.saveGlucoseTargetRangeSchedule(glucoseTargetRangeSchedule)
            },
            mode: viewModel.mode,
            therapySettingType: .glucoseTargetRange
        )
        .simultaneousGesture(TapGesture().onEnded {
            withAnimation {
                userDidTap = true
            }
        })
    }

    var defaultFirstScheduleItemValue: ClosedRange<HKQuantity> {
        switch displayGlucoseUnit {
        case .milligramsPerDeciliter:
            return DoubleRange(minValue: 100, maxValue: 120).quantityRange(for: displayGlucoseUnit)
        case .millimolesPerLiter:
            return DoubleRange(minValue: 5.6, maxValue: 6.7).quantityRange(for: displayGlucoseUnit)
        default:
            fatalError("Unsupposed glucose unit \(displayGlucoseUnit)")
        }
    }

    var description: Text {
        Text(TherapySetting.glucoseTargetRange.descriptiveText(appName: appName))
    }

    var saveConfirmation: SaveConfirmation {
        crossedThresholds.isEmpty ? .notRequired : .required(confirmationAlertContent)
    }
    
    var instructionalContentIfNecessary: some View {
        return Group {
            if viewModel.mode == .acceptanceFlow && !userDidTap {
                instructionalContent
            }
        }
    }
    
    var instructionalContent: some View {
        HStack { // to align with guardrail warning, if present
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedString("You can edit a setting by tapping into any line item.", comment: "Description of how to edit setting"))
                Text(LocalizedString("You can add different ranges for different times of day by using the ➕.", comment: "Description of how to add a configuration range"))
            }
            .foregroundColor(.secondary)
            .font(.subheadline)
            Spacer()
        }
    }

    var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.crossedThresholds
        return Group {
            if !crossedThresholds.isEmpty && (userDidTap || viewModel.mode == .settings) {
                CorrectionRangeGuardrailWarning(crossedThresholds: crossedThresholds)
            }
        }
    }

    var crossedThresholds: [SafetyClassification.Threshold] {
        scheduleItems.flatMap { (item) -> [SafetyClassification.Threshold] in
            let lowerBound = item.value.lowerBound
            let upperBound = item.value.upperBound
            return [lowerBound, upperBound].compactMap { (bound) -> SafetyClassification.Threshold? in
                switch viewModel.guardrail.classification(for: bound) {
                case .withinRecommendedRange:
                    return nil
                case .outsideRecommendedRange(let threshold):
                    return threshold
                }
            }
        }
    }

    private var confirmationAlertContent: AlertContent {
        AlertContent(
            title: Text(LocalizedString("Save Correction Range(s)?", comment: "Alert title for confirming correction ranges outside the recommended range")),
            message: Text(TherapySetting.glucoseTargetRange.guardrailSaveWarningCaption)
        )
    }
}

private struct CorrectionRangeGuardrailWarning: View {
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
            return Text(LocalizedString("Low Correction Value", comment: "Title text for the low correction value warning"))
        case .aboveRecommended, .maximum:
            return Text(LocalizedString("High Correction Value", comment: "Title text for the high correction value warning"))
        }
    }

    private var multipleWarningTitle: Text {
        Text(LocalizedString("Correction Values", comment: "Title text for multi-value correction value warning"))
    }
}
