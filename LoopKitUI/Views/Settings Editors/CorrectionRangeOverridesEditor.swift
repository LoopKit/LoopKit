//
//  CorrectionRangeOverridesEditor.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit

public struct CorrectionRangeOverridesEditor: View {
    let viewModel: CorrectionRangeOverridesEditorViewModel

    @State private var userDidTap: Bool = false

    @State var value: CorrectionRangeOverrides

    @State var showingConfirmationAlert = false
    @State var showEditPresetSheet = false

    var initialValue: CorrectionRangeOverrides {
        viewModel.correctionRangeOverrides
    }

    var preset: CorrectionRangeOverrides.Preset {
        viewModel.preset
    }
    
    public init(
        therapySettingsViewModel: TherapySettingsViewModel,
        preset: CorrectionRangeOverrides.Preset,
        didSave: (() -> Void)? = nil
    ) {
        let viewModel = CorrectionRangeOverridesEditorViewModel(
            therapySettingsViewModel: therapySettingsViewModel,
            preset: preset,
            didSave: didSave)
        self._value = State(initialValue: viewModel.correctionRangeOverrides)
        self.viewModel = viewModel
    }

    public var body: some View {
        ConfigurationPage(
            title: Text(preset.therapySetting.title),
            actionButtonTitle: Text("Confirm Preset"),
            secondaryActionButtonTitle: Text("Edit Preset"),
            cards: {
                // TODO: Figure out why I need to explicitly return a CardStack with 1 card here
                CardStack(cards: [card(for: preset)])
            },
            actionAreaContent: {},
            action: {
                startSaving()
            },
            secondaryAction: {
                showEditPresetSheet = true
            }
        )
        .sheet(isPresented: $showEditPresetSheet) {
            EditPresetView(
                preset: SelectablePreset.preMeal(range: value.preMeal ?? viewModel.correctionRangeScheduleRange),
                scheduledRange: value.preMeal ?? viewModel.correctionRangeScheduleRange,
                trainingCompletion: .init(allowDebugFeatures: false),
                onSave: { value = .init(preMeal: $0.correctionRange) },
                onDelete: { _ in },
                correctionRangeGuardrailForPreset: { _ in viewModel.guardrail },
                impactForInsulinMultiplier: { _ in (basalRate: nil, carbRatio: nil, isf: nil) },
                showPresetsTrainingSheet: {},
                suspendThreshold: { viewModel.suspendThreshold }
            )
        }
        .simultaneousGesture(TapGesture().onEnded {
            withAnimation {
                self.userDidTap = true
            }
        })
    }

    private func card(for preset: CorrectionRangeOverrides.Preset) -> Card {
        Card {
            PresetCard(
                presetId: "pre-meal",
                icon: .image("Pre-Meal-symbol", tint: .preMeal),
                presetName: "Pre-Meal",
                duration: .untilCarbsEntered,
                insulinMultiplier: 1,
                correctionRange: value.preMeal,
                guardrail: nil,
                expectedEndTime: nil,
                isScheduled: false,
                activityPresetIsModified: nil,
                activePresetId: { nil },
                effectiveCorrectionRange: { nil },
            )
            .padding(-16)
            .onTapGesture {
                showEditPresetSheet = true
            }
        }
    }
    
    private func startSaving() {
        viewModel.saveCorrectionRangeOverride(value)
    }
}
