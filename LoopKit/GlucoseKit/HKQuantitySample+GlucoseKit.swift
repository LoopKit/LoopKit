//
//  GlucoseValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import HealthKit
import LoopAlgorithm

let MetadataKeyGlucoseIsDisplayOnly = "com.loudnate.GlucoseKit.HKMetadataKey.GlucoseIsDisplayOnly"
let MetadataKeyGlucoseCondition = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseCondition"
let MetadataKeyGlucoseTrend = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrend"
let MetadataKeyGlucoseTrendRateValue = "com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrendRateValue"

public struct LoopQuantitySample: GlucoseSampleValue {
    
    public let hkQuantitySample: HKQuantitySample
    
    public init(with sample: HKQuantitySample) {
        self.hkQuantitySample = sample
    }
    
    public var provenanceIdentifier: String {
        hkQuantitySample.provenanceIdentifier
    }
    
    public var isDisplayOnly: Bool {
        hkQuantitySample.isDisplayOnly
    }
    
    public var wasUserEntered: Bool {
        hkQuantitySample.wasUserEntered
    }
    
    public var condition: GlucoseCondition? {
        hkQuantitySample.condition
    }
    
    public var trendRate: LoopQuantity? {
        hkQuantitySample.trendRate
    }
    
    public var quantity: LoopQuantity {
        guard let unit = LoopUnit.firstCompatible(with: hkQuantitySample.quantity) else {
            fatalError()
        }
        
        return LoopQuantity(unit: unit, doubleValue: hkQuantitySample.quantity.doubleValue(for: unit.hkUnit))
    }
    
    public var startDate: Date {
        hkQuantitySample.startDate
    }
}

extension HKQuantitySample {
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

    public var trendRate: LoopQuantity? {
        guard let value = metadata?[MetadataKeyGlucoseTrendRateValue] as? Double else {
            return nil
        }
        return LoopQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: value)
    }
}
