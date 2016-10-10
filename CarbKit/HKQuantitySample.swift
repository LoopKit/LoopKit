//
//  HKQuantitySample.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/10/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit


let MetadataKeyAbsorptionTimeMinutes = "com.loudnate.CarbKit.HKMetadataKey.AbsorptionTimeMinutes"


extension HKQuantitySample {
    public var foodType: String? {
        return metadata?[HKMetadataKeyFoodType] as? String
    }

    public var absorptionTime: TimeInterval? {
        return metadata?[MetadataKeyAbsorptionTimeMinutes] as? TimeInterval
    }

    public var createdByCurrentApp: Bool {
        return sourceRevision.source == HKSource.default()
    }
}
