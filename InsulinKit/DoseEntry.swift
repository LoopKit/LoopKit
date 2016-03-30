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
    public let startDate: NSDate
    public let endDate: NSDate
    public let value: Double
    public let unit: DoseUnit
    public let description: String?
    let managedObjectID: NSManagedObjectID? = nil

    public init(startDate: NSDate, endDate: NSDate, value: Double, unit: DoseUnit, description: String? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.unit = unit
        self.description = description
    }
}
