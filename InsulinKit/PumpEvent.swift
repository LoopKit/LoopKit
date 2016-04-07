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
        return date
    }

    var endDate: NSDate {
        return date.dateByAddingTimeInterval(duration)
    }
}
