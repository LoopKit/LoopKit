//
//  TherapySettingsViewModel.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Combine
import LoopKit
import SwiftUI

public protocol TherapySettingsViewModelDelegate: AnyObject {
    func syncBasalRateSchedule(items: [RepeatingScheduleValue<Double>], completion: @escaping (Result<BasalRateSchedule, Error>) -> Void)
    func syncDeliveryLimits(deliveryLimits: DeliveryLimits) async throws -> DeliveryLimits
    func saveCompletion(therapySettings: TherapySettings)
    func pumpSupportedIncrements() -> PumpSupportedIncrements?
    /// Throws when settings edited from `therapySettings` can no longer be saved, for example because the active
    /// profile or its schedules changed while the editor was open. Nothing is synced or saved then.
    func validateTherapySettingsEdit(from therapySettings: TherapySettings) throws
}

public extension TherapySettingsViewModelDelegate {
    func validateTherapySettingsEdit(from therapySettings: TherapySettings) throws {}
}

@Observable
public class TherapySettingsViewModel {
    
    public var therapySettings: TherapySettings

    /// Why the last change was not saved, until the settings screen shows it.
    public var saveError: Error?
    
    @ObservationIgnored private let initialTherapySettings: TherapySettings
    @ObservationIgnored public var prescription: Prescription?

    @ObservationIgnored private weak var delegate: TherapySettingsViewModelDelegate?
    
    public init(therapySettings: TherapySettings,
                pumpSupportedIncrements: (() -> PumpSupportedIncrements?)? = nil,
                prescription: Prescription? = nil,
                delegate: TherapySettingsViewModelDelegate? = nil) {
        self.therapySettings = therapySettings
        self.initialTherapySettings = therapySettings
        self.prescription = prescription
        self.delegate = delegate
    }

    var deliveryLimits: DeliveryLimits {
        return DeliveryLimits(maximumBasalRate: therapySettings.maximumBasalRatePerHour.map { LoopQuantity(unit: .internationalUnitsPerHour, doubleValue: $0) },
                              maximumBolus: therapySettings.maximumBolus.map { LoopQuantity(unit: .internationalUnit, doubleValue: $0) } )
    }

    var suspendThreshold: GlucoseThreshold? {
        return therapySettings.suspendThreshold
    }

    

    var glucoseTargetRangeSchedule: GlucoseRangeSchedule? {
        return therapySettings.glucoseTargetRangeSchedule
    }

    func glucoseTargetRangeSchedule(for glucoseUnit: LoopUnit) -> GlucoseRangeSchedule? {
        return glucoseTargetRangeSchedule?.schedule(for: glucoseUnit)
    }

    var correctionRangeOverrides: CorrectionRangeOverrides {
        return CorrectionRangeOverrides(preMeal: therapySettings.correctionRangeOverrides?.preMeal)
    }

    var correctionRangeScheduleRange: ClosedRange<LoopQuantity> {
        precondition(therapySettings.glucoseTargetRangeSchedule != nil)
        return therapySettings.glucoseTargetRangeSchedule!.scheduleRange()
    }

    var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        return therapySettings.insulinSensitivitySchedule
    }

    func insulinSensitivitySchedule(for glucoseUnit: LoopUnit) -> InsulinSensitivitySchedule? {
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
        do {
            try delegate?.validateTherapySettingsEdit(from: therapySettings)
        } catch {
            completion(.failure(error))
            return
        }
        delegate?.syncBasalRateSchedule(items: items, completion: completion)
    }
    
    public func syncDeliveryLimits(deliveryLimits: DeliveryLimits) async throws -> DeliveryLimits {
        try delegate?.validateTherapySettingsEdit(from: therapySettings)
        return try await delegate?.syncDeliveryLimits(deliveryLimits: deliveryLimits) ?? deliveryLimits
    }

    /// False, with `saveError` set, when the delegate refuses changes made from the settings shown.
    private func canSave() -> Bool {
        do {
            try delegate?.validateTherapySettingsEdit(from: therapySettings)
            return true
        } catch {
            saveError = error
            return false
        }
    }
}

// MARK: Saving
extension TherapySettingsViewModel {
    
    public func saveCorrectionRange(range: GlucoseRangeSchedule) {
        guard canSave() else { return }
        therapySettings.glucoseTargetRangeSchedule = range
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
        
    public func saveCorrectionRangeOverride(preset: CorrectionRangeOverrides.Preset,
                                            correctionRangeOverrides: CorrectionRangeOverrides) {
        guard canSave() else { return }
        therapySettings.correctionRangeOverrides = correctionRangeOverrides
        delegate?.saveCompletion(therapySettings: therapySettings)
    }

    public func saveSuspendThreshold(quantity: LoopQuantity, withDisplayGlucoseUnit displayGlucoseUnit: LoopUnit) {
        guard canSave() else { return }
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
            let adjusted = [overrides.preMeal].map { item -> ClosedRange<LoopQuantity>? in
                guard let item = item else {
                    return nil
                }
                return ClosedRange<LoopQuantity>.init(
                    uncheckedBounds: (
                        lower: max(quantity, item.lowerBound),
                        upper:  max(quantity, item.upperBound)))
            }
            therapySettings.correctionRangeOverrides = CorrectionRangeOverrides(preMeal: adjusted[0])
        }

        if let presets = therapySettings.overridePresets {
            therapySettings.overridePresets = presets.map { preset in
                if let targetRange = preset.settings.targetRange {
                    var newPreset = preset
                    newPreset.settings = TemporaryPresetSettings(
                        targetRange: ClosedRange<LoopQuantity>.init(
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
        guard canSave() else { return }
        therapySettings.basalRateSchedule = basalRates
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
    
    public func saveDeliveryLimits(limits: DeliveryLimits) {
        guard canSave() else { return }
        therapySettings.maximumBasalRatePerHour = limits.maximumBasalRate?.doubleValue(for: .internationalUnitsPerHour)
        therapySettings.maximumBolus = limits.maximumBolus?.doubleValue(for: .internationalUnit)
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
    
    public func saveInsulinModel(insulinModelPreset: ExponentialInsulinModelPreset) {
        guard canSave() else { return }
        therapySettings.defaultRapidActingModel = insulinModelPreset
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
    
    public func saveCarbRatioSchedule(carbRatioSchedule: CarbRatioSchedule) {
        guard canSave() else { return }
        therapySettings.carbRatioSchedule = carbRatioSchedule
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
    
    public func saveInsulinSensitivitySchedule(insulinSensitivitySchedule: InsulinSensitivitySchedule) {
        guard canSave() else { return }
        therapySettings.insulinSensitivitySchedule = insulinSensitivitySchedule
        delegate?.saveCompletion(therapySettings: therapySettings)
    }
}
