//
//  PresetCard.swift
//  Loop
//
//  Created by Cameron Ingham on 10/24/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import SwiftUI

public struct PresetCard: View {
    
    @Environment(\.colorPalette) private var colorPalette
    @Environment(\.isEnabled) private var isEnabled
    @EnvironmentObject var displayGlucosePreference: DisplayGlucosePreference
    
    let presetId: String
    let icon: PresetSymbol?
    let presetName: String
    let duration: PresetDuration
    let insulinMultiplier: Double?
    let correctionRange: ClosedRange<LoopQuantity>?
    let guardrail: Guardrail<LoopQuantity>?
    let expectedEndTime: PresetExpectedEndTime?
    let isScheduled: Bool
    let activityPresetIsModified: Bool?
    
    let activePresetId: () -> String?
    let effectiveCorrectionRange: () -> ClosedRange<LoopQuantity>?
    
    public init(
        presetId: String,
        icon: PresetSymbol?,
        presetName: String,
        duration: PresetDuration,
        insulinMultiplier: Double?,
        correctionRange: ClosedRange<LoopQuantity>?,
        guardrail: Guardrail<LoopQuantity>?,
        expectedEndTime: PresetExpectedEndTime?,
        isScheduled: Bool,
        activityPresetIsModified: Bool?,
        activePresetId: @escaping () -> String?,
        effectiveCorrectionRange: @escaping () -> ClosedRange<LoopQuantity>?
    ) {
        self.presetId = presetId
        self.icon = icon
        self.presetName = presetName
        self.duration = duration
        self.insulinMultiplier = insulinMultiplier
        self.correctionRange = correctionRange
        self.guardrail = guardrail
        self.expectedEndTime = expectedEndTime
        self.isScheduled = isScheduled
        self.activityPresetIsModified = activityPresetIsModified
        self.activePresetId = activePresetId
        self.effectiveCorrectionRange = effectiveCorrectionRange
    }
    
    var presetTitle: some View {
        HStack(spacing: 6) {
            if let icon, !icon.isEmpty {
                PresetSymbolView(icon)
            }

            Text(presetName)
                .fontWeight(.semibold)
                .accessibilityIdentifier("text_Preset\(presetName)")
            
            if activityPresetIsModified == false {
                Text(Image(systemName: "checkmark.seal.fill"))
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    var reminderIcon: some View {
        Text(Image(systemName: "alarm"))
            .font(.footnote)
            .foregroundColor(colorPalette.carbTintColor)
            .accessibilityLabel(Text("Scheduled reminder"))
    }

    var presetDuration: some View {
        Group { Text(Image(systemName: "timer")) + Text(" \(duration.localizedTitle)") }
            .font(.footnote)
            .foregroundColor(.secondary)
            .accessibilityLabel(Text(duration.accessibilityLabel))
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    VStack(alignment: .leading) {
                        if let expectedEndTime {
                            HStack(spacing: 8) {
                                Text(Image(systemName: "timer"))
                                +
                                Text(" \(expectedEndTime.localizedTitle)")
                                    .accessibilityLabel(Text(expectedEndTime.accessibilityLabel))
                            }
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                            .background(Color(colorPalette.chartColorPalette.presetTint))
                            .cornerRadius(8)
                        }
                        presetTitle
                    }

                    Spacer()

                    if expectedEndTime == nil {
                        presetDuration
                        if isScheduled {
                            reminderIcon
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    presetTitle
                    
                    presetDuration
                }
            }
            
            Divider()
                .padding(.horizontal, -10)
            
            PresetStatsView(
                insulinMultiplier: insulinMultiplier,
                correctionRange: correctionRange,
                guardrail: guardrail,
                therapySettingsImpactDisplayState: .hide,
                isScheduled: isScheduled && expectedEndTime != nil,
                isActive: activePresetId() == presetId,
                effectiveCorrectionRange: effectiveCorrectionRange
            )
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(Color(UIColor.tertiarySystemBackground))
            .stroke(Color(UIColor.secondarySystemBackground), lineWidth: 1)
            .frame(maxWidth: .infinity))
        .opacity(isEnabled ? 1 : 0.6)
    }
}

extension Color {
    init(presetSymbolTint: PresetSymbol.SymbolTint?, palette: LoopUIColorPalette) {
        guard let presetSymbolTint else {
            self = .primary
            return
        }
        
        switch presetSymbolTint {
        case .preMeal:
            self = palette.carbTintColor
        }
    }
}

public extension PresetCard {
    @ViewBuilder
    static func `default`(for activityType: ActivityPreset.ActivityType) -> PresetCard {
        
        let defaultDuration = PresetDuration.duration(.minutes(90))
        let defaultPreset = activityType.defaultPreset(duration: defaultDuration.presetDuration, scheduleStartDate: nil, repeatOptions: .none)
        
        PresetCard(
            presetId: defaultPreset.id,
            icon: defaultPreset.symbol,
            presetName: defaultPreset.name,
            duration: defaultDuration,
            insulinMultiplier: defaultPreset.settings.effectiveInsulinNeedsScaleFactor,
            correctionRange: defaultPreset.settings.targetRange,
            guardrail: nil,
            expectedEndTime: nil,
            isScheduled: false,
            activityPresetIsModified: false,
            activePresetId: { nil },
            effectiveCorrectionRange: { nil }
        )
    }
}
