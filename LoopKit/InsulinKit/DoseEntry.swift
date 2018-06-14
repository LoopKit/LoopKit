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

    public init(type: DoseType, startDate: Date, endDate: Date? = nil, value: Double, unit: DoseUnit, description: String? = nil, syncIdentifier: String? = nil, scheduledBasalRate: HKQuantity? = nil) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate ?? startDate
        self.value = value
        self.unit = unit
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

    public var units: Double {
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
            return self.units
        case .basal, .resume, .suspend, .tempBasal:
            break
        }

        guard hours > 0 else {
            return 0
        }

        let units = netBasalUnitsPerHour * hours
        return round(units * DoseEntry.minimumMinimedIncrementPerUnit) / DoseEntry.minimumMinimedIncrementPerUnit
    }

    /// The rate of delivery, net the basal rate scheduled during that time, which can be used to compute insulin on-board and glucose effects
    public var netBasalUnitsPerHour: Double {
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
    /// TODO: Is this 40 for x23 models?
    internal static let minimumMinimedIncrementPerUnit: Double = 20

    /// Rounds a given entry to the smallest increment of hourly delivery
    internal var unitsRoundedToMinimedIncrements: Double {
        guard case .unitsPerHour = unit else {
            return self.units
        }
        let units = self.units

        return round(units * DoseEntry.minimumMinimedIncrementPerUnit) / DoseEntry.minimumMinimedIncrementPerUnit
    }
}
