//
//  DoseEntry.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/31/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit


public enum DoseUnit {
    case UnitsPerHour
    case Units
}


public struct DoseEntry: TimelineValue {
    public let startDate: NSDate
    public let endDate: NSDate
    public let value: Double
    public let unit: DoseUnit
    public let description: String?
}
