//
//  SuspendThresholdEditorViewModel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-01.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

struct SuspendThresholdEditorViewModel {
    var suspendThreshold: HKQuantity?

    var suspendThresholdUnit: HKUnit

    let glucoseTargetRangeSchedule: GlucoseRangeSchedule?

    var maxSuspendThresholdValue: HKQuantity

    let mode: SettingsPresentationMode

    var saveSuspendThreshold: (_ suspendThreshold: HKQuantity, _ displayGlucoseUnit: HKUnit) -> Void

    let guardrail = Guardrail.suspendThreshold

    public init(therapySettingsViewModel: TherapySettingsViewModel,
                didSave: (() -> Void)? = nil)
    {
        self.suspendThreshold = therapySettingsViewModel.suspendThreshold?.quantity
        self.suspendThresholdUnit = therapySettingsViewModel.suspendThreshold?.unit ?? .milligramsPerDeciliter
        self.glucoseTargetRangeSchedule = therapySettingsViewModel.therapySettings.glucoseTargetRangeSchedule

        self.maxSuspendThresholdValue = Guardrail.maxSuspendThresholdValue(
            correctionRangeSchedule: glucoseTargetRangeSchedule,
            preMealTargetRange: therapySettingsViewModel.therapySettings.preMealTargetRange,
            workoutTargetRange: therapySettingsViewModel.therapySettings.workoutTargetRange)
        
        self.mode = therapySettingsViewModel.mode
        self.saveSuspendThreshold = { [weak therapySettingsViewModel] suspendThreshold, displayGlucoseUnit in
            guard let therapySettingsViewModel = therapySettingsViewModel else {
                return
            }
            therapySettingsViewModel.saveSuspendThreshold(quantity: suspendThreshold, withDisplayGlucoseUnit: displayGlucoseUnit)
            didSave?()
        }
    }
}
