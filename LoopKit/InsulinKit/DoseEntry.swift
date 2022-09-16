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
    public let insulinType: InsulinType?
    public let automatic: Bool?
    public let manuallyEntered: Bool
    public internal(set) var syncIdentifier: String?
    public let isMutable: Bool
    public let wasProgrammedByPumpUI: Bool

    /// The scheduled basal rate during this dose entry
    public internal(set) var scheduledBasalRate: HKQuantity?

    public init(suspendDate: Date, automatic: Bool? = nil, isMutable: Bool = false, wasProgrammedByPumpUI: Bool = false) {
        self.init(type: .suspend, startDate: suspendDate, value: 0, unit: .units, automatic: automatic, isMutable: isMutable, wasProgrammedByPumpUI: wasProgrammedByPumpUI)
    }

    public init(resumeDate: Date, insulinType: InsulinType? = nil, automatic: Bool? = nil, isMutable: Bool = false, wasProgrammedByPumpUI: Bool = false) {
        self.init(type: .resume, startDate: resumeDate, value: 0, unit: .units, insulinType: insulinType, automatic: automatic, isMutable: isMutable, wasProgrammedByPumpUI: wasProgrammedByPumpUI)
    }

    // If the insulin model field is nil, it's assumed that the model is the type of insulin the pump dispenses
    public init(type: DoseType, startDate: Date, endDate: Date? = nil, value: Double, unit: DoseUnit, deliveredUnits: Double? = nil, description: String? = nil, syncIdentifier: String? = nil, scheduledBasalRate: HKQuantity? = nil, insulinType: InsulinType? = nil, automatic: Bool? = nil, manuallyEntered: Bool = false, isMutable: Bool = false, wasProgrammedByPumpUI: Bool = false) {
        self.type = type
        self.startDate = startDate
        self.endDate = endDate ?? startDate
        self.value = value
        self.unit = unit
        self.deliveredUnits = deliveredUnits
        self.description = description
        self.syncIdentifier = syncIdentifier
        self.scheduledBasalRate = scheduledBasalRate
        self.insulinType = insulinType
        self.automatic = automatic
        self.manuallyEntered = manuallyEntered
        self.isMutable = isMutable
        self.wasProgrammedByPumpUI = wasProgrammedByPumpUI
    }
}


extension DoseEntry {
    public static var units = HKUnit.internationalUnit()
    
    public static let unitsPerHour = HKUnit.internationalUnit().unitDivided(by: .hour())

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
        case .basal:
            return 0
        case .bolus:
            return self.unitsPerHour
        default:
            break
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

extension DoseEntry: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(DoseType.self, forKey: .type)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.endDate = try container.decode(Date.self, forKey: .endDate)
        self.value = try container.decode(Double.self, forKey: .value)
        self.unit = try container.decode(DoseUnit.self, forKey: .unit)
        self.deliveredUnits = try container.decodeIfPresent(Double.self, forKey: .deliveredUnits)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.syncIdentifier = try container.decodeIfPresent(String.self, forKey: .syncIdentifier)
        self.insulinType = try container.decodeIfPresent(InsulinType.self, forKey: .insulinType)
        if let scheduledBasalRate = try container.decodeIfPresent(Double.self, forKey: .scheduledBasalRate),
            let scheduledBasalRateUnit = try container.decodeIfPresent(String.self, forKey: .scheduledBasalRateUnit) {
            self.scheduledBasalRate = HKQuantity(unit: HKUnit(from: scheduledBasalRateUnit), doubleValue: scheduledBasalRate)
        }
        self.automatic = try container.decodeIfPresent(Bool.self, forKey: .automatic)
        self.manuallyEntered = try container.decodeIfPresent(Bool.self, forKey: .manuallyEntered) ?? false
        self.isMutable = try container.decodeIfPresent(Bool.self, forKey: .isMutable) ?? false
        self.wasProgrammedByPumpUI = try container.decodeIfPresent(Bool.self, forKey: .wasProgrammedByPumpUI) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(value, forKey: .value)
        try container.encode(unit, forKey: .unit)
        try container.encodeIfPresent(deliveredUnits, forKey: .deliveredUnits)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(syncIdentifier, forKey: .syncIdentifier)
        try container.encodeIfPresent(insulinType, forKey: .insulinType)
        if let scheduledBasalRate = scheduledBasalRate {
            try container.encode(scheduledBasalRate.doubleValue(for: DoseEntry.unitsPerHour), forKey: .scheduledBasalRate)
            try container.encode(DoseEntry.unitsPerHour.unitString, forKey: .scheduledBasalRateUnit)
        }
        try container.encodeIfPresent(automatic, forKey: .automatic)
        try container.encode(manuallyEntered, forKey: .manuallyEntered)
        try container.encode(isMutable, forKey: .isMutable)
        try container.encode(wasProgrammedByPumpUI, forKey: .wasProgrammedByPumpUI)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case startDate
        case endDate
        case value
        case unit
        case deliveredUnits
        case description
        case syncIdentifier
        case scheduledBasalRate
        case scheduledBasalRateUnit
        case insulinType
        case automatic
        case manuallyEntered
        case isMutable
        case wasProgrammedByPumpUI
    }
}

extension DoseEntry: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: [String: Any]) {
        guard let rawType = rawValue["type"] as? DoseType.RawValue,
              let type = DoseType(rawValue: rawType),
              let startDate = rawValue["startDate"] as? Date,
              let endDate = rawValue["endDate"] as? Date,
              let value = rawValue["value"] as? Double,
              let rawUnit = rawValue["unit"] as? DoseUnit.RawValue,
              let unit = DoseUnit(rawValue: rawUnit),
              let manuallyEntered = rawValue["manuallyEntered"] as? Bool
        else {
            return nil
        }

        self.type = type
        self.startDate = startDate
        self.endDate = endDate
        self.value = value
        self.unit = unit
        self.manuallyEntered = manuallyEntered

        self.deliveredUnits = rawValue["deliveredUnits"] as? Double
        self.description = rawValue["description"] as? String
        self.insulinType = (rawValue["insulinType"] as? InsulinType.RawValue).flatMap { InsulinType(rawValue: $0) }
        self.automatic = rawValue["automatic"] as? Bool
        self.syncIdentifier = rawValue["syncIdentifier"] as? String
        self.scheduledBasalRate = (rawValue["scheduledBasalRate"] as? Double).flatMap { HKQuantity(unit: .internationalUnitsPerHour, doubleValue: $0) }
        self.isMutable = rawValue["isMutable"] as? Bool ?? false
        self.wasProgrammedByPumpUI = rawValue["wasProgrammedByPumpUI"] as? Bool ?? false
    }

    public var rawValue: [String: Any] {
        var rawValue: [String: Any] = [
            "type": type.rawValue,
            "startDate": startDate,
            "endDate": endDate,
            "value": value,
            "unit": unit.rawValue,
            "manuallyEntered": manuallyEntered,
            "isMutable": isMutable,
            "wasProgrammedByPumpUI": wasProgrammedByPumpUI
        ]

        rawValue["deliveredUnits"] = deliveredUnits
        rawValue["description"] = description
        rawValue["insulinType"] = insulinType?.rawValue
        rawValue["automatic"] = automatic
        rawValue["syncIdentifier"] = syncIdentifier
        rawValue["scheduledBasalRate"] = scheduledBasalRate?.doubleValue(for: .internationalUnitsPerHour)

        return rawValue
    }
}
