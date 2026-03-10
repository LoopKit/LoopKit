//
//  SuspendThresholdEditorViewModel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-01.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm
import LoopKit

struct SuspendThresholdEditorViewModel {
    let guardrail = Guardrail.suspendThreshold

    let suspendThreshold: LoopQuantity?

    let suspendThresholdUnit: LoopUnit

    let maxSuspendThresholdValue: LoopQuantity

    var saveSuspendThreshold: (_ suspendThreshold: LoopQuantity, _ displayGlucoseUnit: LoopUnit) -> Void

    public init(therapySettingsViewModel: TherapySettingsViewModel,
                mode: SettingsPresentationMode,
                didSave: (() -> Void)? = nil)
    {
        self.suspendThreshold = therapySettingsViewModel.suspendThreshold?.quantity
        self.suspendThresholdUnit = therapySettingsViewModel.suspendThreshold?.unit ?? .milligramsPerDeciliter

        if mode == .acceptanceFlow {
            // During a review/acceptance flow, do not limit suspend threshold by other targets
            self.maxSuspendThresholdValue = Guardrail.suspendThreshold.absoluteBounds.upperBound
        } else {
            self.maxSuspendThresholdValue = Guardrail.maxSuspendThresholdValue(minimumConfiguredLowerBound: therapySettingsViewModel.therapySettings.minimumConfiguredTargetLowerBound)
        }
        
        self.saveSuspendThreshold = { [weak therapySettingsViewModel] suspendThreshold, displayGlucoseUnit in
            guard let therapySettingsViewModel = therapySettingsViewModel else {
                return
            }
            therapySettingsViewModel.saveSuspendThreshold(quantity: suspendThreshold, withDisplayGlucoseUnit: displayGlucoseUnit)
            didSave?()
        }
    }
}
