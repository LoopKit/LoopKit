//
//  PumpEvent.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData


class PumpEvent: NSManagedObject {

    var doseType: DoseType? {
        get {
            willAccessValue(forKey: "doseType")
            defer { didAccessValue(forKey: "doseType") }
            return DoseType(rawValue: primitiveDoseType ?? "")
        }
        set {
            willChangeValue(forKey: "doseType")
            defer { didChangeValue(forKey: "doseType") }
            primitiveDoseType = newValue?.rawValue
        }
    }

    var duration: TimeInterval! {
        get {
            willAccessValue(forKey: "duration")
            defer { didAccessValue(forKey: "duration") }
            return primitiveDuration?.doubleValue
        }
        set {
            willChangeValue(forKey: "duration")
            defer { didChangeValue(forKey: "duration") }
            primitiveDuration = newValue != nil ? NSNumber(value: newValue) : nil
        }
    }

    var unit: DoseUnit? {
        get {
            willAccessValue(forKey: "unit")
            defer { didAccessValue(forKey: "unit") }
            return DoseUnit(rawValue: primitiveUnit ?? "")
        }
        set {
            willChangeValue(forKey: "unit")
            defer { didChangeValue(forKey: "unit") }
            primitiveUnit = newValue?.rawValue
        }
    }

    var type: PumpEventType? {
        get {
            willAccessValue(forKey: "type")
            defer { didAccessValue(forKey: "type") }
            return PumpEventType(rawValue: primitiveType ?? "")
        }
        set {
            willChangeValue(forKey: "type")
            defer { didChangeValue(forKey: "type") }
            primitiveType = newValue?.rawValue
        }
    }

    var uploaded: Bool {
        get {
            willAccessValue(forKey: "uploaded")
            defer { didAccessValue(forKey: "uploaded") }
            return primitiveUploaded?.boolValue ?? false
        }
        set {
            willChangeValue(forKey: "uploaded")
            defer { didChangeValue(forKey: "uploaded") }
            primitiveUploaded = NSNumber(value: newValue)
        }
    }

    var value: Double? {
        get {
            willAccessValue(forKey: "value")
            defer { didAccessValue(forKey: "value") }
            return primitiveValue?.doubleValue
        }
        set {
            willChangeValue(forKey: "value")
            defer { didChangeValue(forKey: "value") }
            primitiveValue = newValue != nil ? NSNumber(value: newValue!) : nil
        }
    }

    var deliveredUnits: Double? {
        get {
            willAccessValue(forKey: "deliveredUnits")
            defer { didAccessValue(forKey: "deliveredUnits") }
            return primitiveDeliveredUnits?.doubleValue
        }
        set {
            willChangeValue(forKey: "deliveredUnits")
            defer { didChangeValue(forKey: "deliveredUnits") }
            primitiveDeliveredUnits = newValue != nil ? NSNumber(value: newValue!) : nil
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


extension PumpEvent: TimelineValue {
    var startDate: Date {
        get {
            return date
        }
        set {
            date = newValue
        }
    }

    var endDate: Date {
        get {
            return date.addingTimeInterval(duration)
        }
        set {
            duration = newValue.timeIntervalSince(startDate)
        }
    }
}


extension PumpEvent {

    var dose: DoseEntry? {
        get {
            // To handle migration, we're requiring any dose to also have a PumpEventType
            guard let type = type, let value = value, let unit = unit else {
                return nil
            }

            return DoseEntry(
                type: doseType ?? DoseType(pumpEventType: type)!,
                startDate: startDate,
                endDate: endDate,
                value: value,
                unit: unit,
                deliveredUnits: deliveredUnits,
                syncIdentifier: syncIdentifier
            )
        }
        set {
            guard let entry = newValue else {
                return
            }
            
            doseType = entry.type
            startDate = entry.startDate
            endDate = entry.endDate
            value = entry.value
            unit = entry.unit
            deliveredUnits = entry.deliveredUnits
        }
    }

    var syncIdentifier: String? {
        return raw?.hexadecimalString
    }

    var isUploaded: Bool {
        return uploaded
    }

    var isMutable: Bool {
        return mutable
    }
}

extension PumpEvent {
    func update(from event: PersistedPumpEvent) {
        createdAt = event.persistedDate
        date = event.date
        type = event.type
        uploaded = event.isUploaded
        mutable = event.isMutable
        raw = event.raw
        title = event.title
        dose = event.dose
    }
}
