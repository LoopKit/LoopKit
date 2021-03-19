//
//  InsulinSensitivityScheduleEditorViewModel.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-15.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit

struct InsulinSensitivityScheduleEditorViewModel {
    var saveInsulinSensitivitySchedule: (_ insulinSensitivitySchedule: InsulinSensitivitySchedule) -> Void

    let mode: SettingsPresentationMode

    let insulinSensitivitySchedule: InsulinSensitivitySchedule?

    init(therapySettingsViewModel: TherapySettingsViewModel,
         didSave: (() -> Void)? = nil)
    {
        self.mode = therapySettingsViewModel.mode
        self.insulinSensitivitySchedule = therapySettingsViewModel.insulinSensitivitySchedule
        self.saveInsulinSensitivitySchedule = { [weak therapySettingsViewModel] insulinSensitivitySchedule in
            guard let therapySettingsViewModel = therapySettingsViewModel else {
                return
            }

            therapySettingsViewModel.saveInsulinSensitivitySchedule(insulinSensitivitySchedule: insulinSensitivitySchedule)
            didSave?()
        }
    }
}
