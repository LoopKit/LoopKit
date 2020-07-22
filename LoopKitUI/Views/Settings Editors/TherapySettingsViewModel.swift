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
    public typealias SaveCompletion = (TherapySetting, TherapySettings) -> Void
    
    @Published public var therapySettings: TherapySettings
    public var supportedInsulinModelSettings: SupportedInsulinModelSettings
    private let didSave: SaveCompletion?

    private let initialTherapySettings: TherapySettings
    let pumpSupportedIncrements: PumpSupportedIncrements?
    let syncPumpSchedule: PumpManager.SyncSchedule?
    let sensitivityOverridesEnabled: Bool
    let prescription: Prescription?
    let includeSupportSection: Bool

    public init(therapySettings: TherapySettings,
                supportedInsulinModelSettings: SupportedInsulinModelSettings = SupportedInsulinModelSettings(fiaspModelEnabled: true, walshModelEnabled: true),
                pumpSupportedIncrements: PumpSupportedIncrements? = nil,
                syncPumpSchedule: PumpManager.SyncSchedule? = nil,
                sensitivityOverridesEnabled: Bool = false,
                includeSupportSection: Bool = true,
                prescription: Prescription? = nil,
                didSave: SaveCompletion? = nil) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.pumpSupportedIncrements = pumpSupportedIncrements
        self.syncPumpSchedule = syncPumpSchedule
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.prescription = prescription
        self.supportedInsulinModelSettings = supportedInsulinModelSettings
        self.includeSupportSection = includeSupportSection
        self.didSave = didSave
    }
    
    /// Reset to initial
    public func reset() {
        therapySettings = initialTherapySettings
    }
    
    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
        didSave?(TherapySetting.glucoseTargetRange, therapySettings)
    }
    
    public func saveCorrectionRangeOverrides(overrides: CorrectionRangeOverrides, unit: HKUnit) {
        therapySettings.preMealTargetRange = overrides.preMeal?.doubleRange(for: unit)
        therapySettings.workoutTargetRange = overrides.workout?.doubleRange(for: unit)
        didSave?(TherapySetting.correctionRangeOverrides, therapySettings)
    }
    
    public func saveSuspendThreshold(value: GlucoseThreshold) {
        therapySettings.suspendThreshold = value
        didSave?(TherapySetting.suspendThreshold, therapySettings)
    }
    
    public func saveBasalRates(basalRates: BasalRateSchedule) {
        therapySettings.basalRateSchedule = basalRates
        didSave?(TherapySetting.basalRate, therapySettings)
    }
    
    public func saveDeliveryLimits(limits: DeliveryLimits) {
        therapySettings.maximumBasalRatePerHour = limits.maximumBasalRate?.doubleValue(for: .internationalUnitsPerHour)
        therapySettings.maximumBolus = limits.maximumBolus?.doubleValue(for: .internationalUnit())
        didSave?(TherapySetting.deliveryLimits, therapySettings)
    }
    
    public func saveCarbRatioSchedule(carbRatioSchedule: CarbRatioSchedule) {
        therapySettings.carbRatioSchedule = carbRatioSchedule
        didSave?(TherapySetting.carbRatio, therapySettings)
    }
    
    public func saveInsulinSensitivitySchedule(insulinSensitivitySchedule: InsulinSensitivitySchedule) {
        therapySettings.insulinSensitivitySchedule = insulinSensitivitySchedule
        didSave?(TherapySetting.insulinSensitivity, therapySettings)
    }
}
