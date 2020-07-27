//
//  CorrectionRangeOverrideReviewView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit

public struct CorrectionRangeOverrideReview: View {
    @ObservedObject var viewModel: TherapySettingsViewModel
    private let sensitivityOverridesEnabled: Bool
    private let mode: PresentationMode
    private var unit: HKUnit {
        self.viewModel.therapySettings.glucoseUnit!
    }

    public init(mode: PresentationMode = .acceptanceFlow, viewModel: TherapySettingsViewModel) {
        precondition(viewModel.therapySettings.glucoseUnit != nil)
        precondition(viewModel.therapySettings.glucoseTargetRangeSchedule != nil)
        self.mode = mode
        self.viewModel = viewModel
        self.sensitivityOverridesEnabled = viewModel.sensitivityOverridesEnabled
    }
    
    public var body: some View {
        CorrectionRangeOverridesEditor(
            value: CorrectionRangeOverrides(
                preMeal: viewModel.therapySettings.preMealTargetRange,
                workout: viewModel.therapySettings.workoutTargetRange,
                unit: unit
            ),
            unit: unit,
            correctionRangeScheduleRange: viewModel.therapySettings.glucoseTargetRangeSchedule!.scheduleRange(),
            minValue: viewModel.therapySettings.suspendThreshold?.quantity,
            onSave: { overrides in
                self.viewModel.saveCorrectionRangeOverrides(overrides: overrides, unit: self.unit)
            },
            sensitivityOverridesEnabled: sensitivityOverridesEnabled,
            mode: mode
        )
    }
}
