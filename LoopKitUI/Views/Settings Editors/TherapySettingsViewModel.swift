//
//  TherapySettingsViewModel.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import LoopKit
import HealthKit
import SwiftUI

public class TherapySettingsViewModel: ObservableObject {
    public typealias SaveCompletion = (TherapySetting, TherapySettings) -> Void
    
    public let mode: SettingsPresentationMode
    
    @Published public var therapySettings: TherapySettings
    public var supportedInsulinModelSettings: SupportedInsulinModelSettings
    private let didSave: SaveCompletion?

    private let initialTherapySettings: TherapySettings
    let pumpSupportedIncrements: (() -> PumpSupportedIncrements?)?
    let syncPumpSchedule: (() -> PumpManager.SyncSchedule?)?
    let sensitivityOverridesEnabled: Bool
    public var prescription: Prescription?
    
    let preferredGlucoseUnit: HKUnit

    lazy private var cancellables = Set<AnyCancellable>()
    
    public let chartColors: ChartColorPalette

    public init(mode: SettingsPresentationMode,
                therapySettings: TherapySettings,
                preferredGlucoseUnit: HKUnit,
                supportedInsulinModelSettings: SupportedInsulinModelSettings = SupportedInsulinModelSettings(fiaspModelEnabled: true, walshModelEnabled: true),
                pumpSupportedIncrements: (() -> PumpSupportedIncrements?)? = nil,
                syncPumpSchedule: (() -> PumpManager.SyncSchedule?)? = nil,
                sensitivityOverridesEnabled: Bool = false,
                prescription: Prescription? = nil,
                chartColors: ChartColorPalette,
                didSave: SaveCompletion? = nil) {
        self.mode = mode
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.preferredGlucoseUnit = preferredGlucoseUnit
        self.pumpSupportedIncrements = pumpSupportedIncrements
        self.syncPumpSchedule = syncPumpSchedule
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.prescription = prescription
        self.supportedInsulinModelSettings = supportedInsulinModelSettings
        self.chartColors = chartColors
        self.didSave = didSave
    }
    
    var deliveryLimits: DeliveryLimits {
        return DeliveryLimits(maximumBasalRate: therapySettings.maximumBasalRatePerHour.map { HKQuantity(unit: .internationalUnitsPerHour, doubleValue: $0) },
                              maximumBolus: therapySettings.maximumBolus.map { HKQuantity(unit: .internationalUnit(), doubleValue: $0) } )
    }
    
    /// Reset to initial
    public func reset() {
        therapySettings = initialTherapySettings
    }
    
    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
        didSave?(TherapySetting.glucoseTargetRange, therapySettings)
    }
        
    public func saveCorrectionRangeOverride(preMeal: ClosedRange<HKQuantity>?, unit: HKUnit) {
        therapySettings.preMealTargetRange = preMeal?.doubleRange(for: unit)
        didSave?(TherapySetting.preMealCorrectionRangeOverride, therapySettings)
    }
    
    public func saveCorrectionRangeOverride(workout: ClosedRange<HKQuantity>?, unit: HKUnit) {
        therapySettings.workoutTargetRange = workout?.doubleRange(for: unit)
        didSave?(TherapySetting.workoutCorrectionRangeOverride, therapySettings)
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
    
    public func saveInsulinModel(insulinModelSettings: InsulinModelSettings) {
        therapySettings.insulinModelSettings = insulinModelSettings
        didSave?(TherapySetting.insulinModel, therapySettings)
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
