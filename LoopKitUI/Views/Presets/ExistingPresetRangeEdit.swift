//
//  EditPresetRangeView.swift
//  Loop
//
//  Created by Pete Schwamb on 2/25/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit
import LoopKitUI

struct ExistingPresetRangeEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appName) private var appName

    @Binding var range: ClosedRange<LoopQuantity>?
    var guardrail: Guardrail<LoopQuantity>
    private var scheduledRange: ClosedRange<LoopQuantity>
    @State private var editedRange: ClosedRange<LoopQuantity>?
    private var allowsScheduledRange: Bool
    private var isPreMeal: Bool = false
    private var presetAdjustsInsulinNeeds: Bool
    private var veryHighInsulinNeeds: Bool
    
    let suspendThresholdQuantity: () -> LoopQuantity?

    init(
        range: Binding<ClosedRange<LoopQuantity>?>,
        guardrail: Guardrail<LoopQuantity>,
        scheduledRange: ClosedRange<LoopQuantity>,
        allowsScheduledRange: Bool = true,
        isPreMeal: Bool = false,
        presetAdjustsInsulinNeeds: Bool,
        veryHighInsulinNeeds: Bool,
        suspendThresholdQuantity: @escaping () -> LoopQuantity?
    ) {
        self._range = range
        self.editedRange = range.wrappedValue
        self.guardrail = guardrail
        self.scheduledRange = scheduledRange
        self.allowsScheduledRange = allowsScheduledRange
        self.isPreMeal = isPreMeal
        self.presetAdjustsInsulinNeeds = presetAdjustsInsulinNeeds
        self.veryHighInsulinNeeds = veryHighInsulinNeeds
        self.suspendThresholdQuantity = suspendThresholdQuantity
    }

    var requiresHighInsulinNeedsMitigation: Bool {
        if veryHighInsulinNeeds, let editedRange {
            return editedRange.lowerBound < TemporaryScheduleOverride.highInsulinNeedsMitigationCorrectionRangeLimit
        }
        return veryHighInsulinNeeds
    }

    var highInsulinNeedsWarningText: String {
        String(format: NSLocalizedString("For presets with insulin needs of 170%% or greater, %1$@ will set your correction range to 110 mg/dL or higher when this preset is enabled.", comment: "The format string for the high insulin needs preset warning text. (1: app name)"), appName)
    }

    var body: some View {
        CardSectionScrollView {
            CardSection {
                PresetRangeEditor(
                    range: $editedRange,
                    guardrail: guardrail,
                    scheduledRange: scheduledRange,
                    allowsScheduledRange: allowsScheduledRange,
                    isPreMeal: isPreMeal,
                    suspendThresholdQuantity: suspendThresholdQuantity
                )
            }
        } actionArea: {
            if !crossedThresholds.isEmpty {
                CorrectionRangeGuardrailWarning(crossedThresholds: crossedThresholds)
            } else if (editedRange == nil && !presetAdjustsInsulinNeeds) {
                NoticeView(
                    title: Text("Set an Adjusted Correction Range"),
                    caption: Text("With overall insulin needs at 100%, an adjusted correction range is required."))
            } else if requiresHighInsulinNeedsMitigation {
                WarningView(
                    title: Text("Correction range adjustment when preset is enabled"),
                    caption: Text(highInsulinNeedsWarningText))
            }
            actionButton
        }
        .navigationBarBackButtonHidden(editedRange != range)
        .navigationBarItems(
            trailing: cancelButton
        )
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Edit Preset")
    }

    private var cancelButton: some View {
        Group {
            if editedRange != range {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.blue)
                .accessibilityIdentifier("button_Cancel")
            }
        }
    }


    private var actionButton: some View {
        Button("Save") {
            range = editedRange
            dismiss()
        }
        .disabled(editedRange == range || (editedRange == nil && !presetAdjustsInsulinNeeds))
        .buttonStyle(ActionButtonStyle(.primary))
        .accessibilityIdentifier("button_Save")
    }


    var crossedThresholds: [SafetyClassification.Threshold] {
        if let range = editedRange ?? range {
            let lowerBound = range.lowerBound
            let upperBound = range.upperBound
            return [lowerBound, upperBound].compactMap { (bound) -> SafetyClassification.Threshold? in
                switch guardrail.classification(for: bound) {
                case .withinRecommendedRange:
                    return nil
                case .outsideRecommendedRange(let threshold):
                    return threshold
                }
            }
        } else {
            return []
        }
    }
}

private struct CorrectionRangeGuardrailWarning: View {
    var crossedThresholds: [SafetyClassification.Threshold]

    var body: some View {
        assert(!crossedThresholds.isEmpty)
        return GuardrailWarning(
            therapySetting: .glucoseTargetRange,
            title: crossedThresholds.count == 1 ? singularWarningTitle(for: crossedThresholds.first!) : multipleWarningTitle,
            thresholds: crossedThresholds
        )
    }

    private func singularWarningTitle(for threshold: SafetyClassification.Threshold) -> Text {
        switch threshold {
        case .minimum, .belowWarning, .belowRecommended:
            return Text("Low Correction Value", comment: "Title text for the low correction value warning")
        case .aboveRecommended, .aboveWarning, .maximum:
            return Text("High Correction Value", comment: "Title text for the high correction value warning")
        }
    }

    private var multipleWarningTitle: Text {
        Text("Correction Values", comment: "Title text for multi-value correction value warning")
    }
}
