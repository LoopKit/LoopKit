//
//  HKQuantitySample+InsulinKit.swift
//  InsulinKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit


/// Defines the scheduled basal insulin rate during the time of the basal delivery sample
let MetadataKeyScheduledBasalRate = "com.loopkit.InsulinKit.MetadataKeyScheduledBasalRate"

/// Defines the programmed rate for a temporary basal dose
let MetadataKeyProgrammedTempBasalRate = "com.loopkit.InsulinKit.MetadataKeyProgrammedTempBasalRate"

/// A crude determination of whether a sample was written by LoopKit, in the case of multiple LoopKit-enabled app versions on the same phone.
let MetadataKeyHasLoopKitOrigin = "HasLoopKitOrigin"

/// Defines the insulin curve type to use to evaluate the dose's activity
let MetadataKeyInsulinModelType = "com.loopkit.InsulinKit.MetadataKeyInsulinModelType"

/// Defines the insulin curve duration, if the insulin curve is a Walsh model
let MetadataKeyInsulinModelDuration = "com.loopkit.InsulinKit.MetadataKeyInsulinModelDuration"

public enum CachedInsulinModel: Int {
    case none = 0
    case exponentialAdult
    case exponentialChild
    case fiasp
    case walsh
}

extension HKQuantitySample {
    convenience init?(type: HKQuantityType, unit: HKUnit, dose: DoseEntry, device: HKDevice?, syncVersion: Int = 1) {
        let units = dose.unitsInDeliverableIncrements

        guard let syncIdentifier = dose.syncIdentifier else {
            return nil
        }

        var metadata: [String: Any] = [
            HKMetadataKeySyncVersion: syncVersion,
            HKMetadataKeySyncIdentifier: syncIdentifier,
            MetadataKeyHasLoopKitOrigin: true,
            MetadataKeyInsulinModelType: CachedInsulinModel.none.rawValue,
            MetadataKeyInsulinModelDuration: 0
        ]

        switch dose.type {
        case .basal, .tempBasal, .suspend:
            // Ignore 0-duration basal entries
            guard dose.endDate.timeIntervalSince(dose.startDate) > .ulpOfOne else {
                return nil
            }

            metadata[HKMetadataKeyInsulinDeliveryReason] = HKInsulinDeliveryReason.basal.rawValue

            if let basalRate = dose.scheduledBasalRate {
                metadata[MetadataKeyScheduledBasalRate] = basalRate
            }

            if dose.type == .tempBasal {
                metadata[MetadataKeyProgrammedTempBasalRate] = HKQuantity(unit: .internationalUnitsPerHour, doubleValue: dose.unitsPerHour)
            }
        case .bolus:
            // Ignore 0-unit bolus entries
            guard units > .ulpOfOne else {
                return nil
            }

            metadata[HKMetadataKeyInsulinDeliveryReason] = HKInsulinDeliveryReason.bolus.rawValue
        case .resume:
            return nil
        }
        
        switch dose.insulinModelSetting {
        case .none:
            metadata[MetadataKeyInsulinModelType] = CachedInsulinModel.none.rawValue
        case .exponentialPreset(let preset):
            switch preset {
            case .humalogNovologAdult:
                metadata[MetadataKeyInsulinModelType] = CachedInsulinModel.exponentialAdult.rawValue
            case .humalogNovologChild:
                metadata[MetadataKeyInsulinModelType] = CachedInsulinModel.exponentialChild.rawValue
            case .fiasp:
                metadata[MetadataKeyInsulinModelType] = CachedInsulinModel.fiasp.rawValue
            }
        case .walsh(let model):
            metadata[MetadataKeyInsulinModelType] = CachedInsulinModel.walsh.rawValue
            metadata[MetadataKeyInsulinModelDuration] = model.actionDuration
        }

        self.init(
            type: type,
            quantity: HKQuantity(unit: unit, doubleValue: units),
            start: dose.startDate,
            end: dose.endDate,
            device: device,
            metadata: metadata
        )
    }

    var hasLoopKitOrigin: Bool {
        guard let hasLoopKitOrigin = metadata?[MetadataKeyHasLoopKitOrigin] as? Bool else {
            return false
        }

        return hasLoopKitOrigin
    }

    var insulinDeliveryReason: HKInsulinDeliveryReason? {
        guard let reason = metadata?[HKMetadataKeyInsulinDeliveryReason] as? HKInsulinDeliveryReason.RawValue else {
            return nil
        }

        return HKInsulinDeliveryReason(rawValue: reason)
    }

    var scheduledBasalRate: HKQuantity? {
        return metadata?[MetadataKeyScheduledBasalRate] as? HKQuantity
    }

    var programmedTempBasalRate: HKQuantity? {
        return metadata?[MetadataKeyProgrammedTempBasalRate] as? HKQuantity
    }
    
    var insulinModelSetting: InsulinModelSettings? {
        guard let rawType = metadata?[MetadataKeyInsulinModelType] as? Int, let modelType = CachedInsulinModel(rawValue: rawType) else {
            return nil
        }

        var insulinModelSetting: InsulinModelSettings? = nil
        switch modelType {
        case .exponentialAdult:
            insulinModelSetting = InsulinModelSettings(model: ExponentialInsulinModelPreset.humalogNovologAdult)
        case .exponentialChild:
            insulinModelSetting = InsulinModelSettings(model: ExponentialInsulinModelPreset.humalogNovologChild)
        case .fiasp:
            insulinModelSetting = InsulinModelSettings(model: ExponentialInsulinModelPreset.fiasp)
        case .walsh:
            guard let duration = metadata?[MetadataKeyInsulinModelDuration] as? TimeInterval, duration > 0 else {
                break
            }
            insulinModelSetting = InsulinModelSettings(model: WalshInsulinModel(actionDuration: duration))
        default:
            break
        }

        return insulinModelSetting
    }

    /// Returns a DoseEntry representation of the sample.
    /// Doses are not normalized, nor should they be assumed reconciled.
    var dose: DoseEntry? {
        guard let reason = insulinDeliveryReason else {
            return nil
        }

        let type: DoseType
        let scheduledBasalRate = self.scheduledBasalRate

        switch reason {
        case .basal:
            if scheduledBasalRate == nil {
                type = .basal
            } else {
                type = .tempBasal
            }

            // We can't properly trust non-LoopKit-provided basal insulin
            guard hasLoopKitOrigin else {
                return nil
            }
        case .bolus:
            type = .bolus
        @unknown default:
            return nil
        }

        let value: Double
        let unit: DoseUnit
        let deliveredUnits: Double?

        if let programmedRate = programmedTempBasalRate {
            value = programmedRate.doubleValue(for: .internationalUnitsPerHour)
            unit = .unitsPerHour
            deliveredUnits = quantity.doubleValue(for: .internationalUnit())
        } else {
            value = quantity.doubleValue(for: .internationalUnit())
            unit = .units
            deliveredUnits = nil
        }

        return DoseEntry(
            type: type,
            startDate: startDate,
            endDate: endDate,
            value: value,
            unit: unit,
            deliveredUnits: deliveredUnits,
            description: nil,
            syncIdentifier: metadata?[HKMetadataKeySyncIdentifier] as? String,
            scheduledBasalRate: scheduledBasalRate,
            insulinModelSetting: insulinModelSetting
        )
    }
}
