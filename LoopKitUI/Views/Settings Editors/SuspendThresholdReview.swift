//
//  SuspendThresholdReview.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

public struct SuspendThresholdReview: View {
    @ObservedObject var viewModel: TherapySettingsViewModel
    private let mode: PresentationMode
    private var unit: HKUnit {
        return viewModel.therapySettings.glucoseUnit!
    }
    
    public init(mode: PresentationMode = .acceptanceFlow, viewModel: TherapySettingsViewModel) {
        precondition(viewModel.therapySettings.glucoseUnit != nil)
        self.viewModel = viewModel
        self.mode = mode
    }
    
    public var body: some View {
        SuspendThresholdEditor(
            value: viewModel.therapySettings.suspendThreshold?.quantity,
            unit: unit,
            maxValue: Guardrail.maxSuspendThresholdValue(
                correctionRangeSchedule: viewModel.therapySettings.glucoseTargetRangeSchedule,
                preMealTargetRange: viewModel.therapySettings.preMealTargetRange,
                workoutTargetRange: viewModel.therapySettings.workoutTargetRange,
                unit: unit
            ),
            onSave: { newValue in
                self.viewModel.saveSuspendThreshold(value: GlucoseThreshold(unit: self.unit, value: newValue.doubleValue(for: self.unit)))
            },
            mode: mode
        )
    }
}
