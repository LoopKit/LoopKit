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
    func saveCompletion(therapySettings: TherapySettings)
    func pumpSupportedIncrements() -> PumpSupportedIncrements?
}

public class TherapySettingsViewModel: ObservableObject {
    
    @Published public var therapySettings: TherapySettings
    private let initialTherapySettings: TherapySettings
    let sensitivityOverridesEnabled: Bool
    let adultChildInsulinModelSelectionEnabled: Bool
    public var prescription: Prescription?

    private weak var delegate: TherapySettingsViewModelDelegate?
    
    public init(therapySettings: TherapySettings,
                pumpSupportedIncrements: (() -> PumpSupportedIncrements?)? = nil,
                sensitivityOverridesEnabled: Bool = false,
                adultChildInsulinModelSelectionEnabled: Bool = false,
                prescription: Prescription? = nil,
                delegate: TherapySettingsViewModelDelegate? = nil) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.sensitivityOverridesEnabled = sensitivityOverridesEnabled
        self.adultChildInsulinModelSelectionEnabled = adultChildInsulinModelSelectionEnabled
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
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
        
    public func saveCorrectionRangeOverride(preset: CorrectionRangeOverrides.Preset,
                                            correctionRangeOverrides: CorrectionRangeOverrides) {
        therapySettings.correctionRangeOverrides = correctionRangeOverrides
        delegate?.saveCompletion(therapySettings: therapySettings)
    }

    public func saveSuspendThreshold(quantity: HKQuantity, withDisplayGlucoseUnit displayGlucoseUnit: HKUnit) {
        therapySettings.suspendThreshold = GlucoseThreshold(unit: displayGlucoseUnit, value: quantity.doubleValue(for: displayGlucoseUnit))

        // TODO: Eventually target editors should support conflicting initial values
        // But for now, ensure target ranges do not conflict with suspend threshold.
        if let targetSchedule = therapySettings.glucoseTargetRangeSchedule {
            let threshold = quantity.doubleValue(for: targetSchedule.unit)
            let newItems = targetSchedule.items.map { item in
                return RepeatingScheduleValue<DoubleRange>.init(
                    startTime: item.startTime,
                    value: DoubleRange(
                        minValue: max(threshold, item.value.minValue),
                        maxValue: max(threshold, item.value.maxValue)))
            }
            therapySettings.glucoseTargetRangeSchedule = GlucoseRangeSchedule(unit: targetSchedule.unit, dailyItems: newItems)
        }

        if let overrides = therapySettings.correctionRangeOverrides {
            let adjusted = [overrides.preMeal, overrides.workout].map { item -> ClosedRange<HKQuantity>? in
                guard let item = item else {
                    return nil
                }
                return ClosedRange<HKQuantity>.init(
                    uncheckedBounds: (
                        lower: max(quantity, item.lowerBound),
                        upper:  max(quantity, item.upperBound)))
            }
            therapySettings.correctionRangeOverrides = CorrectionRangeOverrides(
                preMeal: adjusted[0],
                workout: adjusted[1])
        }

        if let presets = therapySettings.overridePresets {
            therapySettings.overridePresets = presets.map { preset in
                if let targetRange = preset.settings.targetRange {
                    var newPreset = preset
                    newPreset.settings = TemporaryScheduleOverrideSettings(
                        targetRange: ClosedRange<HKQuantity>.init(
                            uncheckedBounds: (
                                lower: max(quantity, targetRange.lowerBound),
                                upper:  max(quantity, targetRange.upperBound))),
                        insulinNeedsScaleFactor: preset.settings.insulinNeedsScaleFactor)
                    return newPreset
                } else {
                    return preset
                }
            }
        }

        delegate?.saveCompletion(therapySettings: therapySettings)
    }
    
    public func saveBasalRates(basalRates: BasalRateSchedule) {
        therapySettings.basalRateSchedule = basalRates
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
    
    public func saveDeliveryLimits(limits: DeliveryLimits) {
        therapySettings.maximumBasalRatePerHour = limits.maximumBasalRate?.doubleValue(for: .internationalUnitsPerHour)
        therapySettings.maximumBolus = limits.maximumBolus?.doubleValue(for: .internationalUnit())
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
    
    public func saveInsulinModel(insulinModelPreset: ExponentialInsulinModelPreset) {
        therapySettings.defaultRapidActingModel = insulinModelPreset
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
    
    public func saveCarbRatioSchedule(carbRatioSchedule: CarbRatioSchedule) {
        therapySettings.carbRatioSchedule = carbRatioSchedule
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
    
    public func saveInsulinSensitivitySchedule(insulinSensitivitySchedule: InsulinSensitivitySchedule) {
        therapySettings.insulinSensitivitySchedule = insulinSensitivitySchedule
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
}
