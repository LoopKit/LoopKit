//
//  DoseEntry.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/31/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData
import HealthKit
import LoopKit


public struct DoseEntry: TimelineValue {
    public let type: DoseType
    public let startDate: Date
    public let endDate: Date
    internal let value: Double
    public let unit: DoseUnit
    public let description: String?
    internal(set) public var syncIdentifier: String?
    let managedObjectID: NSManagedObjectID?

    /// The scheduled basal rate during this dose entry
    internal var scheduledBasalRate: HKQuantity?

    public init(type: DoseType, startDate: Date, endDate: Date? = nil, value: Double, unit: DoseUnit, description: String? = nil) {
        self.init(type: type, startDate: startDate, endDate: endDate, value: value, unit: unit, description: description, syncIdentifier: nil, managedObjectID: nil)
    }

    public init(suspendDate: Date) {
        self.init(type: .suspend, startDate: suspendDate, value: 0, unit: .units)
    }

    public init(resumeDate: Date) {
        self.init(type: .resume, startDate: resumeDate, value: 0, unit: .units)
    }

    init(type: DoseType, startDate: Date, endDate: Date? = nil, value: Double, unit: DoseUnit, description: String? = nil, syncIdentifier: String?, managedObjectID: NSManagedObjectID?) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate ?? startDate
        self.value = value
        self.unit = unit
        self.description = description
        self.syncIdentifier = syncIdentifier
        self.managedObjectID = managedObjectID
    }
}


extension DoseEntry {
    public var units: Double {
        switch unit {
        case .units:
            return value
        case .unitsPerHour:
            return value * endDate.timeIntervalSince(startDate).hours
        }
    }

    public var unitsPerHour: Double {
        switch unit {
        case .units:
            let hours = endDate.timeIntervalSince(startDate).hours
            guard hours != 0 else {
                return 0
            }

            return value / hours
        case .unitsPerHour:
            return value
        }
    }

    /// The smallest increment per unit of hourly basal delivery
    /// TODO: Is this 40 for x23 models?
    internal static let minimumMinimedIncrementPerUnit: Double = 20

    /// Rounds down a given entry to the smallest increment of hourly delivery
    internal var unitsFlooredToMinimedIncrements: Double {
        guard case .unitsPerHour = unit else {
            return self.units
        }
        let units = self.units

        return floor(units * DoseEntry.minimumMinimedIncrementPerUnit) / DoseEntry.minimumMinimedIncrementPerUnit
    }

    /// Rounds a given entry to the smallest increment of hourly delivery
    internal var unitsRoundedToMinimedIncrements: Double {
        guard case .unitsPerHour = unit else {
            return self.units
        }
        let units = self.units

        return round(units * DoseEntry.minimumMinimedIncrementPerUnit) / DoseEntry.minimumMinimedIncrementPerUnit
    }
}
