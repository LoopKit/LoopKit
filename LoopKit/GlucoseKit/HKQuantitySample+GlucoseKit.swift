//
//  GlucoseValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit


let MetadataKeyGlucoseIsDisplayOnly = "com.loudnate.GlucoseKit.HKMetadataKey.GlucoseIsDisplayOnly"
let MetadataKeyGlucoseCondition = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseCondition"
let MetadataKeyGlucoseTrend = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrend"
let MetadataKeyGlucoseTrendRateUnit = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrendRateUnit"
let MetadataKeyGlucoseTrendRateValue = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrendRateValue"


extension HKQuantitySample: GlucoseSampleValue {
    public var provenanceIdentifier: String {
        return sourceRevision.source.bundleIdentifier
    }

    public var isDisplayOnly: Bool {
        return metadata?[MetadataKeyGlucoseIsDisplayOnly] as? Bool ?? false
    }

    public var wasUserEntered: Bool {
        return metadata?[HKMetadataKeyWasUserEntered] as? Bool ?? false
    }

    public var condition: GlucoseCondition? {
        guard let rawCondition = metadata?[MetadataKeyGlucoseCondition] as? String else {
            return nil
        }
        return GlucoseCondition(rawValue: rawCondition)
    }

    public var trend: GlucoseTrend? {
        guard let symbol = metadata?[MetadataKeyGlucoseTrend] as? String else {
            return nil
        }
        return GlucoseTrend(symbol: symbol)
    }

    public var trendRate: HKQuantity? {
        guard let unit = metadata?[MetadataKeyGlucoseTrendRateUnit] as? String,
              let value = metadata?[MetadataKeyGlucoseTrendRateValue] as? Double else {
            return nil
        }
        return HKQuantity(unit: HKUnit(from: unit), doubleValue: value)
    }
}
