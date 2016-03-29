//
//  Dose.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData
import LoopKit


class Dose: NSManagedObject {

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

    var type: DoseType? {
        get {
            willAccessValueForKey("type")
            defer { didAccessValueForKey("type") }
            return DoseType(rawValue: primitiveType ?? "")
        }
        set {
            willChangeValueForKey("type")
            defer { didChangeValueForKey("type") }
            primitiveType = newValue?.rawValue
        }
    }

    override func awakeFromInsert() {
        super.awakeFromInsert()

        createdAt = NSDate()
    }
}


extension Dose: Fetchable { }


extension Dose: TimelineValue {
    var startDate: NSDate {
        return date
    }

    var endDate: NSDate {
        return date.dateByAddingTimeInterval(duration)
    }
}
