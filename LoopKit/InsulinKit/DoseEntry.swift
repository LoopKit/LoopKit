//
//  DoseEntry.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/31/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public struct DoseEntry: TimelineValue, Equatable {
    public let type: DoseType
    public let startDate: Date
    public let endDate: Date
    internal let value: Double
    public let unit: DoseUnit
    public let deliveredUnits: Double?
    public let description: String?
    internal(set) public var syncIdentifier: String?

    /// The scheduled basal rate during this dose entry
    internal var scheduledBasalRate: HKQuantity?

    public init(suspendDate: Date) {
        self.init(type: .suspend, startDate: suspendDate, value: 0, unit: .units)
    }

    public init(resumeDate: Date) {
        self.init(type: .resume, startDate: resumeDate, value: 0, unit: .units)
    }

    public init(type: DoseType, startDate: Date, endDate: Date? = nil, value: Double, unit: DoseUnit, deliveredUnits: Double? = nil, description: String? = nil, syncIdentifier: String? = nil, scheduledBasalRate: HKQuantity? = nil) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate ?? startDate
        self.value = value
        self.unit = unit
        self.deliveredUnits = deliveredUnits
        self.description = description
        self.syncIdentifier = syncIdentifier
        self.scheduledBasalRate = scheduledBasalRate
    }
}


extension DoseEntry {
    static let unitsPerHour = HKUnit.internationalUnit().unitDivided(by: .hour())

    private var hours: Double {
        return endDate.timeIntervalSince(startDate).hours
    }

    public var programmedUnits: Double {
        switch unit {
        case .units:
            return value
        case .unitsPerHour:
            return value * hours
        }
    }

    public var unitsPerHour: Double {
        switch unit {
        case .units:
            let hours = self.hours
            guard hours != 0 else {
                return 0
            }

            return value / hours
        case .unitsPerHour:
            return value
        }
    }

    /// The number of units delivered, net the basal rate scheduled during that time, which can be used to compute insulin on-board and glucose effects
    public var netBasalUnits: Double {
        switch type {
        case .bolus:
            return deliveredUnits ?? programmedUnits
        case .basal:
            return 0
        case .resume, .suspend, .tempBasal:
            break
        }

        guard hours > 0 else {
            return 0
        }

        let scheduledUnitsPerHour: Double
        if let basalRate = scheduledBasalRate {
            scheduledUnitsPerHour = basalRate.doubleValue(for: DoseEntry.unitsPerHour)
        } else {
            scheduledUnitsPerHour = 0
        }

        let scheduledUnits = scheduledUnitsPerHour * hours
        return unitsInDeliverableIncrements - scheduledUnits
    }

    /// The rate of delivery, net the basal rate scheduled during that time, which can be used to compute insulin on-board and glucose effects
    public var netBasalUnitsPerHour: Double {
        switch type {
        case .bolus:
            return self.unitsPerHour
        default:
            break;
        }
        
        guard let basalRate = scheduledBasalRate else {
            return 0
        }

        let unitsPerHour = self.unitsPerHour - basalRate.doubleValue(for: DoseEntry.unitsPerHour)

        guard abs(unitsPerHour) > .ulpOfOne else {
            return 0
        }

        return unitsPerHour
    }

    /// The smallest increment per unit of hourly basal delivery
    /// TODO: Is this 40 for x23 models? (yes - PS 7/26/2019)
    /// MinimedPumpmanager will be updated to report deliveredUnits, so this will end up not being used.
    private static let minimumMinimedIncrementPerUnit: Double = 20

    /// Returns the delivered units, or rounds to nearest deliverable (mdt) increment
    public var unitsInDeliverableIncrements: Double {
        guard case .unitsPerHour = unit else {
            return deliveredUnits ?? programmedUnits
        }

        return deliveredUnits ?? round(programmedUnits * DoseEntry.minimumMinimedIncrementPerUnit) / DoseEntry.minimumMinimedIncrementPerUnit
    }
}
