//
//  StoredCarbEntry.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/22/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit

private let unit = HKUnit.gram()


struct StoredCarbEntry: CarbEntry {

    let sampleUUID: UUID

    // MARK: - SampleValue

    let startDate: Date
    let quantity: HKQuantity

    // MARK: - CarbEntry

    let foodType: String?
    let absorptionTime: TimeInterval?
    let createdByCurrentApp: Bool

    init(sample: HKQuantitySample, createdByCurrentApp: Bool? = nil) {
        self.init(sampleUUID: sample.uuid, startDate: sample.startDate, unitString: unit.unitString, value: sample.quantity.doubleValue(for: unit), foodType: sample.foodType, absorptionTime: sample.absorptionTime, createdByCurrentApp: createdByCurrentApp ?? sample.createdByCurrentApp)

    }

    init(sampleUUID: UUID, startDate: Date, unitString: String, value: Double, foodType: String?, absorptionTime: TimeInterval?, createdByCurrentApp: Bool) {
        self.sampleUUID = sampleUUID
        self.startDate = startDate
        self.quantity = HKQuantity(unit: HKUnit(from: unitString), doubleValue: value)
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
    return (lhs.sampleUUID == rhs.sampleUUID)
}


extension StoredCarbEntry: RawRepresentable {
    typealias RawValue = [String: Any]

    init?(rawValue: RawValue) {
        guard let
            sampleUUIDString = rawValue["sampleUUID"] as? String,
            let sampleUUID = UUID(uuidString: sampleUUIDString),
            let startDate = rawValue["startDate"] as? Date,
            let unitString = rawValue["unitString"] as? String,
            let value = rawValue["value"] as? Double,
            let createdByCurrentApp = rawValue["createdByCurrentApp"] as? Bool else
        {
            return nil
        }

        self.init(
            sampleUUID: sampleUUID,
            startDate: startDate,
            unitString: unitString,
            value: value,
            foodType: rawValue["foodType"] as? String,
            absorptionTime: rawValue["absorptionTime"] as? TimeInterval,
            createdByCurrentApp: createdByCurrentApp
        )
    }

    var rawValue: RawValue {
        var raw: RawValue = [
            "sampleUUID": sampleUUID.uuidString,
            "startDate": startDate,
            "unitString": unit.unitString,
            "value": quantity.doubleValue(for: unit),
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
