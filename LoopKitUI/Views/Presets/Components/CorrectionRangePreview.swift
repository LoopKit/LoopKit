//
//  CorrectionRangePreview.swift
//  Loop
//
//  Created by Pete Schwamb on 3/7/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import SwiftUI

public struct CorrectionRangePreview: View {
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference
    @Environment(\.guidanceColors) private var guidanceColors
    @Environment(\.appName) private var appName

    private var range: ClosedRange<LoopQuantity>?
    private var guardrail: Guardrail<LoopQuantity>
    private var scheduledRange: ClosedRange<LoopQuantity>
    private var showDisclosure: Bool
    private var veryHighInsulinNeeds: Bool

    public init(range: ClosedRange<LoopQuantity>?, guardrail: Guardrail<LoopQuantity>, scheduledRange: ClosedRange<LoopQuantity>, veryHighInsulinNeeds: Bool, showDisclosure: Bool = false) {
        self.range = range
        self.guardrail = guardrail
        self.scheduledRange = scheduledRange
        self.veryHighInsulinNeeds = veryHighInsulinNeeds
        self.showDisclosure = showDisclosure
    }

    func boundText(for bound: LoopQuantity) -> Text {
        let color = guardrail.color(for: bound, guidanceColors: guidanceColors)
        let text = displayGlucosePreference.format(bound, includeUnit: false)
        switch guardrail.classification(for: bound) {
        case .withinRecommendedRange:
            return Text(text)
                .foregroundColor(.accentColor)
                .font(.system(size: 34, weight: .bold))
        case .outsideRecommendedRange:
            return (
                Text(text)
                    .foregroundColor(color)
                    .font(.system(size: 34, weight: .bold))
                )
        }
    }

    func correctionRangeLabel(range: ClosedRange<LoopQuantity>) -> Text {
        boundText(for: range.lowerBound) +
        Text("-").foregroundColor(.secondary)
            .font(.system(size: 34, weight: .light))
        +
        boundText(for: range.upperBound) +
        Text(" ") +
        Text(displayGlucosePreference.unit.localizedShortUnitString)
            .font(.system(.body))
            .foregroundColor(.secondary)
            .baselineOffset(12)
    }

    private var correctionRangeCrossedThresholds: [SafetyClassification.Threshold] {
        guard let range else { return [] }

        let thresholds: [SafetyClassification.Threshold] = [range.lowerBound, range.upperBound].compactMap { bound in
            switch guardrail.classification(for: bound) {
            case .withinRecommendedRange:
                return nil
            case .outsideRecommendedRange(let threshold):
                return threshold
            }
        }

        return thresholds
    }

    var requiresHighInsulinNeedsMitigation: Bool {
        if veryHighInsulinNeeds, let range {
            return range.lowerBound < TemporaryScheduleOverride.highInsulinNeedsMitigationCorrectionRangeLimit
        }
        return veryHighInsulinNeeds
    }

    var highInsulinNeedsWarningText: String {
        String(format: NSLocalizedString("%1$@ will set your correction range to 110 mg/dL or higher when this preset is enabled.", comment: "The format string for the high insulin needs preset warning text on the preset preview screen. (1: app name)"), appName)
    }

    private var guardrailWarningIfNecessary: some View {
        let crossedThresholds = self.correctionRangeCrossedThresholds

        return Group {
            if !crossedThresholds.isEmpty {
                WarningPanel(severity: crossedThresholds.map { $0.severity }.max()!) {
                    Text(SafetyClassification.captionForCrossedThresholds(crossedThresholds, isRange: true))
                        .accessibilityIdentifier("text_CorrectionRangeWarning");
                }
            } else if requiresHighInsulinNeedsMitigation {
                WarningPanel {
                    Text(highInsulinNeedsWarningText)
                }
            }
        }
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Text("Correction Range")
                    .font(.headline)
                Spacer()
                if showDisclosure {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }.padding(.bottom, 10)
            VStack(spacing: 4) {
                if let range {
                    correctionRangeLabel(range: range).accessibilityIdentifier("text_CorrectionRangePreview")
                    Text("Adjusted Range")
                } else {
                    correctionRangeLabel(range: scheduledRange).accessibilityIdentifier("text_CorrectionRangePreview")
                    Text("Scheduled Range")
                }
            }
            guardrailWarningIfNecessary
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.bottom, 5)
                .padding(.horizontal, 2)
        }
        .foregroundColor(.primary)
    }
}
