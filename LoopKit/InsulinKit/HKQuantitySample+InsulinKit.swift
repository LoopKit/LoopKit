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

/// Defines the insulin curve to use to evaluate the dose's activity
let MetadataKeyInsulinCurveType = "com.loopkit.InsulinKit.MetadataKeyInsulinCurveType"

/// Defines the duration of insulin curve to use to evaluate the dose's activity
let MetadataKeyInsulinCurveDuration = "com.loopkit.InsulinKit.MetadataKeyInsulinCurveDuration"

/// Defines the delay of insulin curve to use to evaluate the dose's activity
let MetadataKeyInsulinCurveDelay = "com.loopkit.InsulinKit.MetadataKeyInsulinCurveDelay"

/// Defines the peak of insulin curve to use to evaluate the dose's activity
let MetadataKeyInsulinCurvePeak = "com.loopkit.InsulinKit.MetadataKeyInsulinCurvePeak"

/// A crude determination of whether a sample was written by LoopKit, in the case of multiple LoopKit-enabled app versions on the same phone.
let MetadataKeyHasLoopKitOrigin = "HasLoopKitOrigin"

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
            MetadataKeyInsulinCurveType: 2,
            MetadataKeyInsulinCurveDuration: -1.0,
            MetadataKeyInsulinCurveDelay: -1.0,
            MetadataKeyInsulinCurvePeak: -1.0
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
        
        // Save the insulin model
        // ANNA TODO: could there be an easier way to do this?
        metadata[MetadataKeyInsulinCurveDuration] = dose.insulinModel?.effectDuration
        metadata[MetadataKeyInsulinCurveDelay] = dose.insulinModel?.delay
        // ANNA TODO: could this be more elegant?
        if let model = dose.insulinModel as? ExponentialInsulinModel {
            metadata[MetadataKeyInsulinCurvePeak] = model.peakActivityTime
            metadata[MetadataKeyInsulinCurveType] = InsulinModelType.exponential.rawValue
        } else if let model = dose.insulinModel as? ExponentialInsulinModelPreset {
            // ANNA TODO: is the below bad style?
            metadata[MetadataKeyInsulinCurvePeak] = (model.getExponentialModel() as! ExponentialInsulinModel).peakActivityTime
           metadata[MetadataKeyInsulinCurveType] = InsulinModelType.exponential.rawValue
        } else if let _ = dose.insulinModel as? WalshInsulinModel {
            metadata[MetadataKeyInsulinCurveType] = InsulinModelType.walsh.rawValue
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
    
    
    // ANNA TODO: there's a bug when reading back data from HealthKit
    var insulinModel: InsulinModel? {
        guard let rawType = metadata?[MetadataKeyInsulinCurveType] as? Int, let modelType = InsulinModelType(rawValue: rawType) else {
            return nil
        }
        
        var model: InsulinModel? = nil

        switch modelType {
        case .walsh:
            model = WalshInsulinModel(actionDuration: metadata?[MetadataKeyInsulinCurveDuration] as! TimeInterval, delay: (metadata?[MetadataKeyInsulinCurveDelay] ?? 600) as! TimeInterval)
        case .exponential:
            model = ExponentialInsulinModel(actionDuration: metadata?[MetadataKeyInsulinCurveDuration] as! TimeInterval, peakActivityTime: metadata?[MetadataKeyInsulinCurvePeak] as! TimeInterval, delay: (metadata?[MetadataKeyInsulinCurveDelay] ?? 600.0) as! TimeInterval)
        default:
            break
        }
        
        return model
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
            insulinModel: insulinModel
        )
    }
}
