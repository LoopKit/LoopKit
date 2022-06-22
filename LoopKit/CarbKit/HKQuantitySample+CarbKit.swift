//
//  HKQuantitySample.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/10/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit


let LegacyMetadataKeyAbsorptionTime = "com.loudnate.CarbKit.HKMetadataKey.AbsorptionTimeMinutes"
let MetadataKeyAbsorptionTime = "com.loopkit.AbsorptionTime"
let MetadataKeyUserCreatedDate = "com.loopkit.CarbKit.HKMetadataKey.UserCreatedDate"
let MetadataKeyUserUpdatedDate = "com.loopkit.CarbKit.HKMetadataKey.UserUpdatedDate"

extension HKQuantitySample {
    public var foodType: String? {
        return metadata?[HKMetadataKeyFoodType] as? String
    }

    public var absorptionTime: TimeInterval? {
        return metadata?[MetadataKeyAbsorptionTime] as? TimeInterval
            ?? metadata?[LegacyMetadataKeyAbsorptionTime] as? TimeInterval
    }

    public var createdByCurrentApp: Bool {
        return sourceRevision.source == HKSource.default()
    }

    public var userCreatedDate: Date? {
        return metadata?[MetadataKeyUserCreatedDate] as? Date
    }

    public var userUpdatedDate: Date? {
        return metadata?[MetadataKeyUserUpdatedDate] as? Date
    }
}
