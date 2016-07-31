//
//  DoseEntry.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/31/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData
import LoopKit


public struct DoseEntry: TimelineValue {
    public let type: PumpEventType
    public let startDate: NSDate
    public let endDate: NSDate
    public let value: Double
    public let unit: DoseUnit
    public let description: String?
    let managedObjectID: NSManagedObjectID?

    public init(type: PumpEventType, startDate: NSDate, endDate: NSDate? = nil, value: Double, unit: DoseUnit, description: String? = nil) {
        self.init(type: type, startDate: startDate, endDate: endDate, value: value, unit: unit, description: description, managedObjectID: nil)
    }

    public init(suspendDate: NSDate) {
        self.init(type: .suspend, startDate: suspendDate, value: 0, unit: .unitsPerHour)
    }

    public init(resumeDate: NSDate) {
        self.init(type: .resume, startDate: resumeDate, value: 0, unit: .unitsPerHour)
    }

    init(type: PumpEventType, startDate: NSDate, endDate: NSDate? = nil, value: Double, unit: DoseUnit, description: String? = nil, managedObjectID: NSManagedObjectID?) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate ?? startDate
        self.value = value
        self.unit = unit
        self.description = description
        self.managedObjectID = managedObjectID
    }
}
