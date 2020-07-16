//
//  TherapySettingsViewModel.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import HealthKit

public class TherapySettingsViewModel: ObservableObject {
    private var initialTherapySettings: TherapySettings
    public var therapySettings: TherapySettings
    public var didFinishStep: (() -> Void)?

    public init(therapySettings: TherapySettings) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
    }
    
    /// Reset to original
    public func reset() {
        therapySettings = initialTherapySettings
    }
    
    public func reset(settings: TherapySettings) {
        initialTherapySettings = settings
        therapySettings = initialTherapySettings
    }
    
    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
    }
    
    public func saveCorrectionRangeOverrides(overrides: CorrectionRangeOverrides, unit: HKUnit) {
        therapySettings.preMealTargetRange = overrides.preMeal?.doubleRange(for: unit)
        therapySettings.workoutTargetRange = overrides.workout?.doubleRange(for: unit)
    }
    
    public func saveSuspendThreshold(value: GlucoseThreshold) {
        therapySettings.suspendThreshold = value
    }
    
    public func saveBasalRates(basalRates: BasalRateSchedule) {
        therapySettings.basalRateSchedule = basalRates
    }
    
    public func saveDeliveryLimits(limits: DeliveryLimits) {
        therapySettings.maximumBasalRatePerHour = limits.maximumBasalRate?.doubleValue(for: .internationalUnitsPerHour)
        therapySettings.maximumBolus = limits.maximumBolus?.doubleValue(for: .internationalUnit())
    }
}
