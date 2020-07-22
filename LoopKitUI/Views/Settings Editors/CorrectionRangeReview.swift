//
//  CorrectionRangeReview.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 6/29/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import SwiftUI
import LoopKit


public struct CorrectionRangeReview: View {
    @ObservedObject var viewModel: TherapySettingsViewModel
    
    private let mode: PresentationMode
    
    public init(mode: PresentationMode = .acceptanceFlow, viewModel: TherapySettingsViewModel) {
        precondition(viewModel.therapySettings.glucoseUnit != nil)
        self.mode = mode
        self.viewModel = viewModel
    }
    
    public var body: some View {
        CorrectionRangeScheduleEditor(
            schedule: viewModel.therapySettings.glucoseTargetRangeSchedule,
            unit: viewModel.therapySettings.glucoseUnit!,
            minValue: viewModel.therapySettings.suspendThreshold?.quantity,
            onSave: { newSchedule in
                self.viewModel.saveCorrectionRange(range: newSchedule)
            },
            mode: mode
        )
    }
}
