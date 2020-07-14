//
//  TherapySettingsViewModel.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

public class TherapySettingsViewModel: ObservableObject {
    private var initialTherapySettings: TherapySettings
    var therapySettings: TherapySettings

    public init(therapySettings: TherapySettings) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
    }
    
    /// Reset to original
    func reset() {
        therapySettings = initialTherapySettings
    }
}
