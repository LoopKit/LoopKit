//
//  GlucoseValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit


let MetadataKeyGlucoseIsDisplayOnly = "com.loudnate.GlucoseKit.HKMetadataKey.GlucoseIsDisplayOnly"
let MetadataKeyGlucoseTrend = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrend"


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
    
    public var trend: GlucoseTrend? {
        return (metadata?[MetadataKeyGlucoseTrend] as? Int).flatMap { GlucoseTrend(rawValue: $0) }
    }
}
