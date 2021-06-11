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
    let guardrail = Guardrail.suspendThreshold

    let suspendThreshold: HKQuantity?

    let suspendThresholdUnit: HKUnit

    let maxSuspendThresholdValue: HKQuantity

    var saveSuspendThreshold: (_ suspendThreshold: HKQuantity, _ displayGlucoseUnit: HKUnit) -> Void

    public init(therapySettingsViewModel: TherapySettingsViewModel,
                didSave: (() -> Void)? = nil)
    {
        self.suspendThreshold = therapySettingsViewModel.suspendThreshold?.quantity
        self.suspendThresholdUnit = therapySettingsViewModel.suspendThreshold?.unit ?? .milligramsPerDeciliter

        self.maxSuspendThresholdValue = Guardrail.maxSuspendThresholdValue(
            correctionRangeSchedule: therapySettingsViewModel.glucoseTargetRangeSchedule,
            preMealTargetRange: therapySettingsViewModel.correctionRangeOverrides.preMeal,
            workoutTargetRange: therapySettingsViewModel.correctionRangeOverrides.workout)
        
        self.saveSuspendThreshold = { [weak therapySettingsViewModel] suspendThreshold, displayGlucoseUnit in
            guard let therapySettingsViewModel = therapySettingsViewModel else {
                return
            }
            therapySettingsViewModel.saveSuspendThreshold(quantity: suspendThreshold, withDisplayGlucoseUnit: displayGlucoseUnit)
            didSave?()
        }
    }
}
