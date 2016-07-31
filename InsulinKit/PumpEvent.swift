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

    var duration: NSTimeInterval! {
        get {
            willAccessValueForKey("duration")
            defer { didAccessValueForKey("duration") }
            return primitiveDuration?.doubleValue
        }
        set {
            willChangeValueForKey("duration")
            defer { didChangeValueForKey("duration") }
            primitiveDuration = newValue != nil ? NSNumber(double: newValue) : nil
        }
    }

    var unit: DoseUnit? {
        get {
            willAccessValueForKey("unit")
            defer { didAccessValueForKey("unit") }
            return DoseUnit(rawValue: primitiveUnit ?? "")
        }
        set {
            willChangeValueForKey("unit")
            defer { didChangeValueForKey("unit") }
            primitiveUnit = newValue?.rawValue
        }
    }

    var type: PumpEventType? {
        get {
            willAccessValueForKey("type")
            defer { didAccessValueForKey("type") }
            return PumpEventType(rawValue: primitiveType ?? "")
        }
        set {
            willChangeValueForKey("type")
            defer { didChangeValueForKey("type") }
            primitiveType = newValue?.rawValue
        }
    }

    var uploaded: Bool {
        get {
            willAccessValueForKey("uploaded")
            defer { didAccessValueForKey("uploaded") }
            return primitiveUploaded?.boolValue ?? false
        }
        set {
            willChangeValueForKey("uploaded")
            defer { didChangeValueForKey("uploaded") }
            primitiveUploaded = NSNumber(bool: newValue)
        }
    }

    var value: Double? {
        get {
            willAccessValueForKey("value")
            defer { didAccessValueForKey("value") }
            return primitiveValue?.doubleValue
        }
        set {
            willChangeValueForKey("value")
            defer { didChangeValueForKey("value") }
            primitiveValue = newValue != nil ? NSNumber(double: newValue!) : nil
        }
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()

        createdAt = NSDate()
    }
}


extension PumpEvent: Fetchable { }


extension PumpEvent: TimelineValue {
    var startDate: NSDate {
        get {
            return date
        }
        set {
            date = newValue
        }
    }

    var endDate: NSDate {
        get {
            return date.dateByAddingTimeInterval(duration)
        }
        set {
            duration = newValue.timeIntervalSinceDate(startDate)
        }
    }
}


extension PumpEvent {
    var doseEntry: DoseEntry? {
        get {
            guard let type = type, value = value, unit = unit else {
                return nil
            }

            return DoseEntry(type: type, startDate: startDate, endDate: endDate, value: value, unit: unit, managedObjectID: objectID)
        }
        set {
            guard let entry = newValue else {
                return
            }

            type = entry.type
            startDate = entry.startDate
            endDate = entry.endDate
            value = entry.value
            unit = entry.unit
        }
    }
}
