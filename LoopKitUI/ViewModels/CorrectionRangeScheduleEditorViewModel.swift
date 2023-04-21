//
//  CorrectionRangeScheduleEditorViewModel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-19.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

struct CorrectionRangeScheduleEditorViewModel {

    let guardrail = Guardrail.correctionRange

    let glucoseTargetRangeSchedule: GlucoseRangeSchedule?

    let minValue: HKQuantity?

    var saveGlucoseTargetRangeSchedule: (_ glucoseTargetRangeSchedule: GlucoseRangeSchedule) -> Void

    init(
        mode: SettingsPresentationMode,
        therapySettingsViewModel: TherapySettingsViewModel,
        didSave: (() -> Void)? = nil
    ) {
        if mode == .acceptanceFlow {
            self.glucoseTargetRangeSchedule = therapySettingsViewModel.glucoseTargetRangeSchedule?.safeSchedule(with: therapySettingsViewModel.suspendThreshold?.quantity)
        }
        else {
            self.glucoseTargetRangeSchedule = therapySettingsViewModel.glucoseTargetRangeSchedule
        }
        self.minValue = Guardrail.minCorrectionRangeValue(suspendThreshold: therapySettingsViewModel.suspendThreshold)
        self.saveGlucoseTargetRangeSchedule = { [weak therapySettingsViewModel] glucoseTargetRangeSchedule in
            guard let therapySettingsViewModel = therapySettingsViewModel else {
                return
            }

            therapySettingsViewModel.saveCorrectionRange(range: glucoseTargetRangeSchedule)
            didSave?()
        }
    }
}
