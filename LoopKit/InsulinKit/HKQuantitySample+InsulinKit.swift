//
//  HKQuantitySample+InsulinKit.swift
//  InsulinKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import HealthKit


/// Defines the scheduled basal insulin rate during the time of the basal delivery sample
let MetadataKeyScheduledBasalRate = "com.loopkit.InsulinKit.MetadataKeyScheduledBasalRate"

/// A crude determination of whether a sample was written by LoopKit, in the case of multiple LoopKit-enabled app versions on the same phone.
let MetadataKeyHasLoopKitOrigin = "HasLoopKitOrigin"

extension HKQuantitySample {
    convenience init?(type: HKQuantityType, unit: HKUnit, dose: DoseEntry, device: HKDevice?) {
        let units = dose.unitsRoundedToMinimedIncrements

        guard let syncIdentifier = dose.syncIdentifier else {
            return nil
        }

        var metadata: [String: Any] = [
            HKMetadataKeySyncVersion: 1,
            HKMetadataKeySyncIdentifier: syncIdentifier,
            MetadataKeyHasLoopKitOrigin: true
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
        case .bolus:
            // Ignore 0-unit bolus entries
            guard units > .ulpOfOne else {
                return nil
            }

            metadata[HKMetadataKeyInsulinDeliveryReason] = HKInsulinDeliveryReason.bolus.rawValue
        case .resume:
            return nil
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

    var insulinDeliveryReason: HKInsulinDeliveryReason? {
        guard let reason = metadata?[HKMetadataKeyInsulinDeliveryReason] as? HKInsulinDeliveryReason.RawValue else {
            return nil
        }

        return HKInsulinDeliveryReason(rawValue: reason)
    }

    /// Returns a DoseEntry representation of the sample.
    /// Doses are not normalized, nor should they be assumed reconciled.
    var dose: DoseEntry? {
        guard let reason = insulinDeliveryReason else {
            return nil
        }

        let type: DoseType
        let scheduledBasalRate = metadata?[MetadataKeyScheduledBasalRate] as? HKQuantity

        switch reason {
        case .basal:
            if scheduledBasalRate == nil {
                type = .basal
            } else {
                type = .tempBasal
            }
        case .bolus:
            type = .bolus
        }

        var entry = DoseEntry(
            type: type,
            startDate: startDate,
            endDate: endDate,
            value: quantity.doubleValue(for: .internationalUnit()),
            unit: .units,
            description: nil,
            syncIdentifier: metadata?[HKMetadataKeySyncIdentifier] as? String
        )

        entry.scheduledBasalRate = scheduledBasalRate

        return entry
    }
}
