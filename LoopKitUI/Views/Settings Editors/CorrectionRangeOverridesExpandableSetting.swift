//
//  CorrectionRangeOverridesExpandableSetting.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


public struct CorrectionRangeOverridesExpandableSetting<ExpandedContent: View>: View {
    @Environment(\.carbTintColor) var carbTintColor
    @Environment(\.glucoseTintColor) var glucoseTintColor
    @Binding var isEditing: Bool
    @Binding var value: CorrectionRangeOverrides
    let preset: CorrectionRangeOverrides.Preset
    let unit: HKUnit
    let suspendThreshold: GlucoseThreshold?
    var correctionRangeScheduleRange: ClosedRange<HKQuantity>
    var expandedContent: () -> ExpandedContent

    public var body: some View {
        ExpandableSetting(
            isEditing: $isEditing,
            leadingValueContent: {
                HStack {
                    preset.icon(usingCarbTintColor: carbTintColor, orGlucoseTintColor: glucoseTintColor)
                    Text(preset.title)
                }
            },
            trailingValueContent: {
                GuardrailConstrainedQuantityRangeView(
                    range: value.ranges[preset],
                    unit: unit,
                    guardrail: self.guardrail(for: preset),
                    isEditing: isEditing,
                    forceDisableAnimations: true
                )
            },
            expandedContent: expandedContent
        )
    }

    private func guardrail(for preset: CorrectionRangeOverrides.Preset) -> Guardrail<HKQuantity> {
        return Guardrail.correctionRangeOverride(for: preset, correctionRangeScheduleRange: correctionRangeScheduleRange, suspendThreshold: suspendThreshold)
    }
}
