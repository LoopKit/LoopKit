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

public protocol TherapySettingsViewModelDelegate: AnyObject {
    func syncBasalRateSchedule(items: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void)
    func syncDeliveryLimits(deliveryLimits: DeliveryLimits, completion: @escaping (Result<DeliveryLimits, Error>) -> Void)
    func saveCompletion(for therapySetting: TherapySetting, therapySettings: TherapySettings)
    func pumpSupportedIncrements() -> PumpSupportedIncrements?
}

public class TherapySettingsViewModel: ObservableObject {
    
    @Published public var therapySettings: TherapySettings
    private let initialTherapySettings: TherapySettings
    let sensitivityOverridesEnabled: Bool
    public var prescription: Prescription?

    private weak var delegate: TherapySettingsViewModelDelegate?
    
    public init(therapySettings: TherapySettings,
                pumpSupportedIncrements: (() -> PumpSupportedIncrements?)? = nil,
                sensitivityOverridesEnabled: Bool = false,
                prescription: Prescription? = nil,
                delegate: TherapySettingsViewModelDelegate? = nil) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.prescription = prescription
        self.delegate = delegate
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
}

// MARK: Passing along to the delegate
extension TherapySettingsViewModel {

    public var maximumBasalScheduleEntryCount: Int? {
        pumpSupportedIncrements()?.maximumBasalScheduleEntryCount
    }

    public func pumpSupportedIncrements() -> PumpSupportedIncrements? {
        return delegate?.pumpSupportedIncrements()
    }

    public func syncBasalRateSchedule(items: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void) {
        delegate?.syncBasalRateSchedule(items: items, completion: completion)
    }
    
    public func syncDeliveryLimits(deliveryLimits: DeliveryLimits, completion: @escaping (Result<DeliveryLimits, Error>) -> Void) {
        delegate?.syncDeliveryLimits(deliveryLimits: deliveryLimits, completion: completion)
    }
}

// MARK: Saving
extension TherapySettingsViewModel {
    
    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        therapySettings.glucoseTargetRangeSchedule = range
        delegate?.saveCompletion(for: TherapySetting.glucoseTargetRange, therapySettings: therapySettings)
    }
        
    public func saveCorrectionRangeOverride(preset: CorrectionRangeOverrides.Preset,
                                            correctionRangeOverrides: CorrectionRangeOverrides) {
        therapySettings.correctionRangeOverrides = correctionRangeOverrides
        switch preset {
        case .preMeal:
            delegate?.saveCompletion(for: TherapySetting.preMealCorrectionRangeOverride, therapySettings: therapySettings)
        case .workout:
            delegate?.saveCompletion(for: TherapySetting.workoutCorrectionRangeOverride, therapySettings: therapySettings)
        }
    }

    public func saveSuspendThreshold(quantity: HKQuantity, withDisplayGlucoseUnit displayGlucoseUnit: HKUnit) {
        therapySettings.suspendThreshold = GlucoseThreshold(unit: displayGlucoseUnit, value: quantity.doubleValue(for: displayGlucoseUnit))
        delegate?.saveCompletion(for: TherapySetting.suspendThreshold, therapySettings: therapySettings)
    }
    
    public func saveBasalRates(basalRates: BasalRateSchedule) {
        therapySettings.basalRateSchedule = basalRates
        delegate?.saveCompletion(for: TherapySetting.basalRate, therapySettings: therapySettings)
    }
    
    public func saveDeliveryLimits(limits: DeliveryLimits) {
        therapySettings.maximumBasalRatePerHour = limits.maximumBasalRate?.doubleValue(for: .internationalUnitsPerHour)
        therapySettings.maximumBolus = limits.maximumBolus?.doubleValue(for: .internationalUnit())
        delegate?.saveCompletion(for: TherapySetting.deliveryLimits, therapySettings: therapySettings)
    }
    
    public func saveInsulinModel(insulinModelPreset: ExponentialInsulinModelPreset) {
        therapySettings.defaultRapidActingModel = insulinModelPreset
        delegate?.saveCompletion(for: TherapySetting.insulinModel, therapySettings: therapySettings)
    }
    
    public func saveCarbRatioSchedule(carbRatioSchedule: CarbRatioSchedule) {
        therapySettings.carbRatioSchedule = carbRatioSchedule
        delegate?.saveCompletion(for: TherapySetting.carbRatio, therapySettings: therapySettings)
    }
    
    public func saveInsulinSensitivitySchedule(insulinSensitivitySchedule: InsulinSensitivitySchedule) {
        therapySettings.insulinSensitivitySchedule = insulinSensitivitySchedule
        delegate?.saveCompletion(for: TherapySetting.insulinSensitivity, therapySettings: therapySettings)
    }
}
