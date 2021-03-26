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
    
    public let chartColors: ChartColorPalette

    public init(mode: SettingsPresentationMode,
                therapySettings: TherapySettings,
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

    var suspendThreshold: GlucoseThreshold? {
        return therapySettings.suspendThreshold
    }

    var glucoseTargetRangeSchedule: GlucoseRangeSchedule? {
        return therapySettings.glucoseTargetRangeSchedule
    }

    func glucoseTargetRangeSchedule(for glucoseUnit: HKUnit) -> GlucoseRangeSchedule? {
        return glucoseTargetRangeSchedule?.schedule(for: glucoseUnit)
    }

    var correctionRangeOverrides: CorrectionRangeOverrides {
        return CorrectionRangeOverrides(preMeal: therapySettings.correctionRangeOverrides?.preMeal,
                                        workout: therapySettings.correctionRangeOverrides?.workout)
    }

    var correctionRangeScheduleRange: ClosedRange<HKQuantity> {
        precondition(therapySettings.glucoseTargetRangeSchedule != nil)
        return therapySettings.glucoseTargetRangeSchedule!.scheduleRange()
    }

    var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        return therapySettings.insulinSensitivitySchedule
    }

    func insulinSensitivitySchedule(for glucoseUnit: HKUnit) -> InsulinSensitivitySchedule? {
        return insulinSensitivitySchedule?.schedule(for: glucoseUnit)
    }

    /// Reset to initial
    public func reset() {
        therapySettings = initialTherapySettings
    }

    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
        didSave?(TherapySetting.glucoseTargetRange, therapySettings)
    }
        
    public func saveCorrectionRangeOverride(preset: CorrectionRangeOverrides.Preset,
                                            correctionRangeOverrides: CorrectionRangeOverrides) {
        therapySettings.correctionRangeOverrides = correctionRangeOverrides
        switch preset {
        case .preMeal:
            didSave?(TherapySetting.preMealCorrectionRangeOverride, therapySettings)
        case .workout:
            didSave?(TherapySetting.workoutCorrectionRangeOverride, therapySettings)
        }
    }

    public func saveSuspendThreshold(quantity: HKQuantity, withDisplayGlucoseUnit displayGlucoseUnit: HKUnit) {
        therapySettings.suspendThreshold = GlucoseThreshold(unit: displayGlucoseUnit, value: quantity.doubleValue(for: displayGlucoseUnit))
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

// MARK: Navigation

extension TherapySettingsViewModel {

    func screen(for setting: TherapySetting) -> (_ dismiss: @escaping () -> Void) -> AnyView {
        switch setting {
        case .suspendThreshold:
            return { dismiss in
                AnyView(SuspendThresholdEditor(therapySettingsViewModel: self, didSave: dismiss).environment(\.dismiss, dismiss))
            }
        case .glucoseTargetRange:
            return { dismiss in
                AnyView(CorrectionRangeScheduleEditor(therapySettingsViewModel: self, didSave: dismiss).environment(\.dismiss, dismiss))
            }
        case .preMealCorrectionRangeOverride:
            return { dismiss in
                AnyView(CorrectionRangeOverridesEditor(therapySettingsViewModel: self, preset: .preMeal, didSave: dismiss).environment(\.dismiss, dismiss))
            }
        case .workoutCorrectionRangeOverride:
            return { dismiss in
                AnyView(CorrectionRangeOverridesEditor(therapySettingsViewModel: self, preset: .workout, didSave: dismiss).environment(\.dismiss, dismiss))
            }
        case .basalRate:
            precondition(self.pumpSupportedIncrements?() != nil)
            return { dismiss in
                AnyView(BasalRateScheduleEditor(therapySettingsViewModel: self, didSave: dismiss).environment(\.dismiss, dismiss))
            }
        case .deliveryLimits:
            precondition(self.pumpSupportedIncrements?() != nil)
            return { dismiss in
                AnyView(DeliveryLimitsEditor(therapySettingsViewModel: self, didSave: dismiss).environment(\.dismiss, dismiss))
            }
        case .insulinModel:
            precondition(self.therapySettings.insulinModelSettings != nil)
            return { dismiss in
                AnyView(InsulinModelSelection(therapySettingsViewModel: self, didSave: dismiss).environment(\.dismiss, dismiss))
            }
        case .carbRatio:
            return { dismiss in
                AnyView(CarbRatioScheduleEditor(therapySettingsViewModel: self, didSave: dismiss).environment(\.dismiss, dismiss))
            }
        case .insulinSensitivity:
            return { dismiss in
                return AnyView(InsulinSensitivityScheduleEditor(therapySettingsViewModel: self, didSave: dismiss).environment(\.dismiss, dismiss))
            }
        case .none:
            break
        }
        return { _ in AnyView(Text("\(setting.title)")) }
    }
}
