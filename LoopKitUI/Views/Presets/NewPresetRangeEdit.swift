//
//  CreatePresetEditRangeView.swift
//  Loop
//
//  Created by Pete Schwamb on 2/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import SwiftUI

struct NewPresetRangeEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appName) private var appName

    @Binding var preset: NewCustomPreset
    @Binding var path: NavigationPath
    var guardrail: Guardrail<LoopQuantity>
    var scheduledRange: ClosedRange<LoopQuantity>
    var onCancel: () -> Void
    
    let suspendThresholdQuantity: () -> LoopQuantity?

    @State private var editedRange: ClosedRange<LoopQuantity>?

    init(preset: Binding<NewCustomPreset>, path: Binding<NavigationPath>, guardrail: Guardrail<LoopQuantity>, scheduledRange: ClosedRange<LoopQuantity>, onCancel: @escaping () -> Void, suspendThresholdQuantity: @escaping () -> LoopQuantity?) {
        self._preset = preset
        self._path = path
        self._editedRange = .init(initialValue: preset.wrappedValue.correctionRange)
        self.guardrail = guardrail
        self.scheduledRange = scheduledRange
        self.onCancel = onCancel
        self.suspendThresholdQuantity = suspendThresholdQuantity
    }

    var requiresHighInsulinNeedsMitigation: Bool {
        if preset.veryHighInsulinNeeds, let editedRange {
            return editedRange.lowerBound < TemporaryScheduleOverride.highInsulinNeedsMitigationCorrectionRangeLimit
        }
        return preset.veryHighInsulinNeeds
    }

    var highInsulinNeedsWarningText: String {
        String(format: NSLocalizedString("For presets with insulin needs of 170%% or greater, %1$@ will set your correction range to 110 mg/dL or higher when this is preset enabled.", comment: "The format string for the high insulin needs preset warning text. (1: app name)"), appName)
    }

    var body: some View {
        CardSectionScrollView {
            CardSection {
                PresetRangeEditor(
                    range: $editedRange,
                    guardrail: guardrail,
                    scheduledRange: scheduledRange,
                    isPreMeal: false,
                    suspendThresholdQuantity: suspendThresholdQuantity
                )
            }
        } actionArea: {
            if !crossedThresholds.isEmpty {
                CorrectionRangeGuardrailWarning(crossedThresholds: crossedThresholds)
            } else if preset.insulinMultiplier == 1 && editedRange == nil {
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

        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Create a Preset")
        .navigationBarItems(
            trailing: cancelButton
        )
    }

    private var cancelButton: some View {
        Button("Cancel") {
            onCancel()
        }
        .foregroundColor(.blue)
    }

    private var actionButtonText: String {
        if editedRange == nil {
            NSLocalizedString("Continue with scheduled range", comment: "Continue button for new preset range edit when range is not edited")
        } else {
            NSLocalizedString("Continue with adjusted range", comment: "Continue button for new preset range edit when range edited")
        }
    }

    private var actionButton: some View {
        Button(actionButtonText) {
            preset.correctionRange = editedRange
            path.append(CreatePresetPage.nameAndSchedule)
        }
        .disabled(preset.insulinMultiplier == 1 && editedRange == nil)
        .buttonStyle(ActionButtonStyle(.primary))
    }


    var crossedThresholds: [SafetyClassification.Threshold] {
        if let range = editedRange ?? preset.correctionRange {
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
