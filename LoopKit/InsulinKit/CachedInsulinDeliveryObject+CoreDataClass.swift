//
//  CachedInsulinDeliveryObject+CoreDataClass.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData
import HealthKit


class CachedInsulinDeliveryObject: NSManagedObject {

    var reason: HKInsulinDeliveryReason! {
        get {
            willAccessValue(forKey: "reason")
            defer { didAccessValue(forKey: "reason") }

            guard let value = primitiveReason?.intValue else {
                return nil
            }

            return HKInsulinDeliveryReason(rawValue: value)
        }
        set {
            willChangeValue(forKey: "reason")
            defer { didChangeValue(forKey: "reason") }

            guard let value = newValue?.rawValue else {
                primitiveReason = nil
                return
            }

            primitiveReason = NSNumber(value: value)
        }
    }

    var scheduledBasalRate: HKQuantity? {
        get {
            willAccessValue(forKey: "scheduledBasalRate")
            defer { didAccessValue(forKey: "scheduledBasalRate") }

            guard let rate = primitiveScheduledBasalRate else {
                return nil
            }

            return HKQuantity(unit: DoseEntry.unitsPerHour, doubleValue: rate.doubleValue)
        }
        set {
            willChangeValue(forKey: "scheduledBasalRate")
            defer { didChangeValue(forKey: "scheduledBasalRate") }

            guard let rate = newValue?.doubleValue(for: DoseEntry.unitsPerHour) else {
                primitiveScheduledBasalRate = nil
                return
            }

            primitiveScheduledBasalRate = NSNumber(value: rate)
        }
    }

    var programmedTempBasalRate: HKQuantity? {
        get {
            willAccessValue(forKey: "programmedTempBasalRate")
            defer { didAccessValue(forKey: "programmedTempBasalRate") }

            guard let rate = primitiveProgrammedTempBasalRate else {
                return nil
            }

            return HKQuantity(unit: DoseEntry.unitsPerHour, doubleValue: rate.doubleValue)
        }
        set {
            willChangeValue(forKey: "programmedTempBasalRate")
            defer { didChangeValue(forKey: "programmedTempBasalRate") }

            guard let rate = newValue?.doubleValue(for: DoseEntry.unitsPerHour) else {
                primitiveProgrammedTempBasalRate = nil
                return
            }

            primitiveProgrammedTempBasalRate = NSNumber(value: rate)
        }
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()

        createdAt = Date()
    }
}


extension CachedInsulinDeliveryObject {
    var dose: DoseEntry! {
        guard let startDate = startDate else {
            return nil
        }

        let type: DoseType

        switch reason! {
        case .basal:
            if scheduledBasalRate == nil {
                type = .basal
            } else {
                type = .tempBasal
            }
        case .bolus:
            type = .bolus
        @unknown default:
            fatalError("CachedInsulinDeliveryObject has unexpected reason value: \(String(describing: reason))")
        }

        let doseValue: Double
        let unit: DoseUnit
        let deliveredUnits: Double?

        if let programmedRate = programmedTempBasalRate {
            doseValue = programmedRate.doubleValue(for: .internationalUnitsPerHour)
            unit = .unitsPerHour
            deliveredUnits = value
        } else {
            doseValue = value
            unit = .units
            deliveredUnits = nil
        }

        return DoseEntry(
            type: type,
            startDate: startDate,
            endDate: endDate,
            value: doseValue,
            unit: unit,
            deliveredUnits: deliveredUnits,
            description: nil,
            syncIdentifier: syncIdentifier,
            scheduledBasalRate: scheduledBasalRate
        )
    }

    func update(from sample: HKQuantitySample) {
        uuid = sample.uuid
        startDate = sample.startDate
        endDate = sample.endDate
        reason = sample.insulinDeliveryReason
        // External doses might not have a syncIdentifier, so use the UUID
        syncIdentifier = sample.metadata?[HKMetadataKeySyncIdentifier] as? String ?? sample.uuid.uuidString
        scheduledBasalRate = sample.scheduledBasalRate
        programmedTempBasalRate = sample.programmedTempBasalRate
        hasLoopKitOrigin = sample.hasLoopKitOrigin
        value = sample.quantity.doubleValue(for: .internationalUnit())
        provenanceIdentifier = sample.provenanceIdentifier
    }
}
