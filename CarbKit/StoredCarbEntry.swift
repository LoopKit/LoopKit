//
//  StoredCarbEntry.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/22/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit

private let unit = HKUnit.gramUnit()


struct StoredCarbEntry: CarbEntry {

    let sampleUUID: NSUUID

    // MARK: - SampleValue

    let startDate: NSDate
    let quantity: HKQuantity

    // MARK: - CarbEntry

    let foodType: String?
    let absorptionTime: NSTimeInterval?
    let createdByCurrentApp: Bool

    init(sample: HKQuantitySample, createdByCurrentApp: Bool? = nil) {
        self.init(sampleUUID: sample.UUID, startDate: sample.startDate, unitString: unit.unitString, value: sample.quantity.doubleValueForUnit(unit), foodType: sample.foodType, absorptionTime: sample.absorptionTime, createdByCurrentApp: createdByCurrentApp ?? sample.createdByCurrentApp)

    }

    init(sampleUUID: NSUUID, startDate: NSDate, unitString: String, value: Double, foodType: String?, absorptionTime: NSTimeInterval?, createdByCurrentApp: Bool) {
        self.sampleUUID = sampleUUID
        self.startDate = startDate
        self.quantity = HKQuantity(unit: HKUnit(fromString: unitString), doubleValue: value)
        self.foodType = foodType
        self.absorptionTime = absorptionTime
        self.createdByCurrentApp = createdByCurrentApp
    }
}


extension StoredCarbEntry: Hashable {
    var hashValue: Int {
        return sampleUUID.hashValue
    }
}


func ==(lhs: StoredCarbEntry, rhs: StoredCarbEntry) -> Bool {
    return lhs.sampleUUID.isEqual(rhs.sampleUUID)
}


extension StoredCarbEntry: RawRepresentable {
    typealias RawValue = [String: AnyObject]

    init?(rawValue: RawValue) {
        guard let
            sampleUUIDString = rawValue["sampleUUID"] as? String,
            sampleUUID = NSUUID(UUIDString: sampleUUIDString),
            startDate = rawValue["startDate"] as? NSDate,
            unitString = rawValue["unitString"] as? String,
            value = rawValue["value"] as? Double,
            createdByCurrentApp = rawValue["createdByCurrentApp"] as? Bool else
        {
            return nil
        }

        self.init(
            sampleUUID: sampleUUID,
            startDate: startDate,
            unitString: unitString,
            value: value,
            foodType: rawValue["foodType"] as? String,
            absorptionTime: rawValue["absorptionTime"] as? NSTimeInterval,
            createdByCurrentApp: createdByCurrentApp
        )
    }

    var rawValue: RawValue {
        var raw: RawValue = [
            "sampleUUID": sampleUUID.UUIDString,
            "startDate": startDate,
            "unitString": unit.unitString,
            "value": quantity.doubleValueForUnit(unit),
            "createdByCurrentApp": createdByCurrentApp
        ]

        if let foodType = foodType {
            raw["foodType"] = foodType
        }

        if let absorptionTime = absorptionTime {
            raw["absorptionTime"] = absorptionTime
        }

        return raw
    }
}