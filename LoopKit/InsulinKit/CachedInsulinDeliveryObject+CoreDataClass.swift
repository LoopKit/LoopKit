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

    var insulinType: InsulinType? {
        get {
            willAccessValue(forKey: "insulinType")
            defer { didAccessValue(forKey: "insulinType") }
            guard let type = primitiveInsulinType else {
                return nil
            }
            return InsulinType(rawValue: type.intValue)
        }
        set {
            willChangeValue(forKey: "insulinType")
            defer { didChangeValue(forKey: "insulinType") }
            primitiveInsulinType = newValue != nil ? NSNumber(value: newValue!.rawValue) : nil
        }
    }
    
    var automaticallyIssued: Bool? {
        get {
            willAccessValue(forKey: "automaticallyIssued")
            defer { didAccessValue(forKey: "automaticallyIssued") }
            return primitiveAutomaticallyIssued?.boolValue
        }
        set {
            willChangeValue(forKey: "automaticallyIssued")
            defer { didChangeValue(forKey: "automaticallyIssued") }
            primitiveAutomaticallyIssued = newValue != nil ? NSNumber(booleanLiteral: newValue!) : nil
        }
    }

    var hasUpdatedModificationCounter: Bool { changedValues().keys.contains("modificationCounter") }

    func updateModificationCounter() { setPrimitiveValue(managedObjectContext!.modificationCounter!, forKey: "modificationCounter") }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        updateModificationCounter()
        createdAt = Date()
    }

    public override func willSave() {
        if isUpdated && !hasUpdatedModificationCounter {
            updateModificationCounter()
        }
        super.willSave()
    }
}

// MARK: - Helpers

extension CachedInsulinDeliveryObject {
    var dose: DoseEntry! {
        let type: DoseType

        switch reason! {
        case .basal:
            if isSuspend {
                type = .suspend
            } else if programmedTempBasalRate != nil {
                type = .tempBasal
            } else {
                type = .basal
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
            deliveredUnits: !isMutable ? deliveredUnits : nil,
            description: nil,
            syncIdentifier: syncIdentifier,
            scheduledBasalRate: scheduledBasalRate,
            insulinType: insulinType,
            automatic: automaticallyIssued,
            manuallyEntered: manuallyEntered,
            isMutable: isMutable,
            wasProgrammedByPumpUI: wasProgrammedByPumpUI
        )
    }
}

extension CachedInsulinDeliveryObject {
    func create(fromExisting sample: HKQuantitySample, on date: Date = Date()) {
        self.uuid = sample.uuid
        self.provenanceIdentifier = sample.provenanceIdentifier
        self.hasLoopKitOrigin = sample.hasLoopKitOrigin
        self.startDate = sample.startDate
        self.endDate = sample.endDate
        self.syncIdentifier = sample.syncIdentifier ?? sample.uuid.uuidString // External doses might not have a syncIdentifier, so use the UUID
        self.value = sample.quantity.doubleValue(for: .internationalUnit())
        self.scheduledBasalRate = sample.scheduledBasalRate
        self.programmedTempBasalRate = sample.programmedTempBasalRate
        self.insulinType = sample.insulinType
        self.automaticallyIssued = sample.automaticallyIssued
        self.manuallyEntered = sample.manuallyEntered
        self.isSuspend = sample.isSuspend
        self.reason = sample.insulinDeliveryReason
        self.createdAt = date
    }
}

extension CachedInsulinDeliveryObject {
    func create(from entry: DoseEntry, by provenanceIdentifier: String, at date: Date) {
        assert(entry.type != .resume)

        self.uuid = nil
        self.provenanceIdentifier = provenanceIdentifier
        self.hasLoopKitOrigin = true
        self.startDate = entry.startDate
        self.endDate = entry.endDate
        self.syncIdentifier = entry.syncIdentifier
        self.value = entry.unitsInDeliverableIncrements
        self.scheduledBasalRate = entry.scheduledBasalRate
        self.programmedTempBasalRate = (entry.type == .tempBasal) ? HKQuantity(unit: .internationalUnitsPerHour, doubleValue: entry.unitsPerHour) : nil
        self.reason = (entry.type == .bolus) ? .bolus : .basal
        self.createdAt = date
        self.deletedAt = nil
        self.insulinType = entry.insulinType
        self.automaticallyIssued = entry.automatic
        self.manuallyEntered = entry.manuallyEntered
        self.isSuspend = (entry.type == .suspend)
        self.isMutable = entry.isMutable
        self.wasProgrammedByPumpUI = entry.wasProgrammedByPumpUI
        updateModificationCounter()  // Maintains modificationCounter order
    }

    func update(from entry: DoseEntry) {
        assert(entry.type != .resume)
        // startDate can change when doses split by basal schedule changes are later split by
        // override enactments/cancels.
        //assert(entry.startDate == startDate)
        assert(entry.syncIdentifier == syncIdentifier)
        if !isMutable {
            assertionFailure("Attempt to update un-mutable dose: \(self) with \(entry)")
        }

        self.startDate = entry.startDate
        self.endDate = entry.endDate
        self.syncIdentifier = entry.syncIdentifier
        self.value = entry.unitsInDeliverableIncrements
        self.scheduledBasalRate = entry.scheduledBasalRate
        self.programmedTempBasalRate = (entry.type == .tempBasal) ? HKQuantity(unit: .internationalUnitsPerHour, doubleValue: entry.unitsPerHour) : nil
        self.reason = (entry.type == .bolus) ? .bolus : .basal
        self.deletedAt = nil
        self.insulinType = entry.insulinType
        self.automaticallyIssued = entry.automatic
        self.manuallyEntered = entry.manuallyEntered
        self.isSuspend = (entry.type == .suspend)
        self.isMutable = entry.isMutable
        self.wasProgrammedByPumpUI = entry.wasProgrammedByPumpUI
        updateModificationCounter()  // Maintains modificationCounter order
    }
}
