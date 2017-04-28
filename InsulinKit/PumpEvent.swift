//
//  PumpEvent.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData
import LoopKit


class PumpEvent: NSManagedObject {

    var duration: TimeInterval! {
        get {
            willAccessValue(forKey: "duration")
            defer { didAccessValue(forKey: "duration") }
            return primitiveDuration?.doubleValue
        }
        set {
            willChangeValue(forKey: "duration")
            defer { didChangeValue(forKey: "duration") }
            primitiveDuration = newValue != nil ? NSNumber(value: newValue as Double) : nil
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
            primitiveUploaded = NSNumber(value: newValue as Bool)
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
            primitiveValue = newValue != nil ? NSNumber(value: newValue! as Double) : nil
        }
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()

        createdAt = Date()
    }
}


extension PumpEvent: Fetchable { }


extension PumpEvent: TimelineValue {
    var startDate: Date {
        get {
            return date as Date
        }
        set {
            date = newValue
        }
    }

    var endDate: Date {
        get {
            return date.addingTimeInterval(duration) as Date
        }
        set {
            duration = newValue.timeIntervalSince(startDate)
        }
    }
}


extension PumpEvent {
    var dose: DoseEntry? {
        get {
            guard let type = type, let value = value, let unit = unit else {
                return nil
            }

            return DoseEntry(type: type, startDate: startDate, endDate: endDate, value: value, unit: unit, managedObjectID: objectID)
        }
    }
    
    func setValuesWith(pumpEventType: PumpEventType?, dose: DoseEntry?) {
        // This could also be done inline in DoseStore.addPumpEvents
        // I'm OK with either place since it's only used once
        if let dose = dose {
            type = dose.type
            startDate = dose.startDate as Date
            endDate = dose.endDate as Date
            value = dose.value
            unit = dose.unit
        }
        
        // PumpEventType takes precedence over the Dose.type if they conflict
        if let pumpEventType = pumpEventType {
            type = pumpEventType
        }
    }

    var isUploaded: Bool {
        return uploaded
    }
}


extension PumpEvent: PersistedPumpEvent {
}
