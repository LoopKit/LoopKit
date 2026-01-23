//
//  CreatePresetView.swift
//  Loop
//
//  Created by Pete Schwamb on 2/15/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit
import SwiftUI


enum CreatePresetPage: Hashable {
    case correctionRange
    case nameAndSchedule
    case summary
}

struct SettingAdjustmentPreview: View {
    
    @Environment(\.colorPalette) private var colorPalette
    
    let value: LoopQuantity
    let displayUnit: LoopUnit
    let name: String
    private let valueFormatter: QuantityFormatter
    private let unitFormatter: QuantityFormatter
    private let highlighted: Bool

    init(value: LoopQuantity, displayUnit: LoopUnit? = nil, name: String, highlighted: Bool = false) {
        self.value = value
        self.displayUnit = displayUnit ?? value.unit
        self.name = name
        self.valueFormatter = QuantityFormatter(for: value.unit)
        self.unitFormatter = QuantityFormatter(for: self.displayUnit)
        if self.displayUnit == .internationalUnitsPerHour {
            // Basal rates get special treatment here. Loop's default max for basal rate is 3 digits,
            // to support pumps that support that. The value shown here does not represent an actual
            // set basal rate, but rather a value computed by loop, used in computing insulin effects,
            // and is somewhat independent of pump supported rates. 2 digits is generally enough
            // precision here.
            self.valueFormatter.numberFormatter.maximumFractionDigits = 2
        }
        
        self.highlighted = highlighted
    }

    var valueRow: some View {
        (Text(valueFormatter.string(from: value, includeUnit: false) ?? "NA")
            .bold() + Text(" ") +
        Text(displayUnit.shortLocalizedUnitString()))
        .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if highlighted {
                valueRow.foregroundColor(colorPalette.insulinTintColor)
            } else {
                valueRow
            }
            Text(name)
        }
    }
}

public struct CreatePresetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var path: NavigationPath
    @State private var preset: NewCustomPreset
    
    let createPreset: (TemporaryPreset) -> Void
    let impactForInsulinMultiplier: (Double) -> TherapySettings.InsulinMultiplierImpact
    let scheduleNextPresetReminder: () async -> Void
    let scheduledRange: () -> ClosedRange<LoopQuantity>?
    let setScheduleOverride: (TemporaryScheduleOverride) -> Void
    let suspendThreshold: () -> GlucoseThreshold?
    
    public init(
        path: NavigationPath = NavigationPath(),
        preset: NewCustomPreset = NewCustomPreset(),
        createPreset: @escaping (TemporaryPreset) -> Void,
        impactForInsulinMultiplier: @escaping (Double) -> TherapySettings.InsulinMultiplierImpact,
        scheduleNextPresetReminder: @escaping () async -> Void,
        scheduledRange: @escaping () -> ClosedRange<LoopQuantity>?,
        setScheduleOverride: @escaping (TemporaryScheduleOverride) -> Void,
        suspendThreshold: @escaping () -> GlucoseThreshold?
    ) {
        self.path = path
        self.preset = preset
        self.createPreset = createPreset
        self.impactForInsulinMultiplier = impactForInsulinMultiplier
        self.scheduleNextPresetReminder = scheduleNextPresetReminder
        self.scheduledRange = scheduledRange
        self.setScheduleOverride = setScheduleOverride
        self.suspendThreshold = suspendThreshold
    }

    public var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Form {
                    InsulinScaleAdjustView(
                        insulinMultiplier: $preset.insulinMultiplier,
                        guardrail: Guardrail.presetInsulinNeeds,
                        impactForInsulinMultiplier: impactForInsulinMultiplier
                    )
                }

                actionArea
            }
            .edgesIgnoringSafeArea(.bottom)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: CreatePresetPage.self) { page in
                switch page {
                case .correctionRange:
                    Group {
                        if let scheduledRange = scheduledRange() {
                            NewPresetRangeEdit(
                                preset: $preset,
                                path: $path,
                                guardrail: Guardrail.temporaryPresetCorrectionRange,
                                scheduledRange: scheduledRange,
                                onCancel: { dismiss() },
                                suspendThresholdQuantity: { suspendThreshold()?.quantity }
                            )
                        }
                    }
                case .nameAndSchedule:
                    CreatePresetNameAndScheduledEdit(preset: $preset, path: $path, onCancel: { dismiss() })
                case .summary:
                    if let scheduledRange = scheduledRange() {
                        ReviewNewPresetView(
                            preset: $preset,
                            path: $path,
                            scheduledRange: scheduledRange,
                            onCancel: { dismiss() },
                            onComplete: { startPreset in
                                dismiss()
                                if let temporaryPreset = preset.temporaryPreset {
                                    if preset.savePreset {
                                        createPreset(temporaryPreset)
                                        Task {
                                            await scheduleNextPresetReminder()
                                        }
                                    }
                                    if startPreset {
                                        setScheduleOverride(temporaryPreset.createOverride(enactTrigger: .local, isCustom: !preset.savePreset))
                                    }
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Create a Preset")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    var exceededThreshold: SafetyClassification.Threshold? {
        switch Guardrail.presetInsulinNeeds.classification(for: .init(unit: .percent, doubleValue: preset.insulinMultiplier * 100)) {
        case .withinRecommendedRange:
            return nil
        case .outsideRecommendedRange(let threshold):
            return threshold
        }

    }

    var guardrailWarningIfNecessary: some View {
        Group {
            if let threshold = exceededThreshold {
                WarningView(title: threshold.insulinNeedsScaleWarningTitle, caption: threshold.insulinNeedsScaleWarningCaption, severity: threshold.severity)
                    .padding()
            }
        }
    }

    private var actionArea: some View {
        VStack(spacing: 0) {
            guardrailWarningIfNecessary
            actionButton
        }
        .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
    }

    private var actionButton: some View {
        Button("Continue") {
            path.append(CreatePresetPage.correctionRange)
        }
        .buttonStyle(ActionButtonStyle(.primary))
        .padding()
    }
}

extension SafetyClassification.Threshold {
    public var insulinNeedsScaleWarningTitle: Text {
        switch self {
        case .belowRecommended, .belowWarning, .minimum:
            return Text("Insulin adjustment is below the safety threshold")
        case .aboveRecommended, .aboveWarning, .maximum:
            return Text("Insulin adjustment is above the safety threshold")
        }
    }

    public var insulinNeedsScaleWarningCaption: Text {
        switch self {
        case .belowRecommended, .belowWarning, .minimum:
            return Text("Using this adjustment may lead to an under delivery of insulin. Monitor your glucose while this preset is in use.")
        case .aboveRecommended:
            return Text("Using this adjustment may lead to an over delivery of insulin. Monitor your glucose while this preset is in use.")
        case .aboveWarning, .maximum:
            return Text("Using this adjustment may lead to an over delivery of insulin and result in serious injury. Monitor your glucose while this preset is in use.")
        }
    }

}
