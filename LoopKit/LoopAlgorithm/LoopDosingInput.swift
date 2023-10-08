//
//  LoopDosingInput.swift
//  LoopKit
//
//  Created by Pete Schwamb on 9/21/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct LoopDosingInput {
    // Currently scheduled basal in U/hr
    public var scheduledBasalRate: Double

    // Expected time range coverage: t to t+6h)
    public var sensitivity: [AbsoluteScheduleValue<HKQuantity>]

    // Expected time range coverage: t to t+6h
    public var carbRatio: [AbsoluteScheduleValue<Double>]

    // Expected time range coverage: t to t+6
    public var target: GlucoseRangeTimeline

    public var maximumBasalRatePerHour: Double? = nil
    public var maximumBolus: Double
    public var suspendThreshold: GlucoseThreshold

    public init(
        scheduledBasalRate: Double,
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        carbRatio: [AbsoluteScheduleValue<Double>],
        target: GlucoseRangeTimeline,
        maximumBasalRatePerHour: Double? = nil,
        maximumBolus: Double,
        suspendThreshold: GlucoseThreshold)
    {
        self.scheduledBasalRate = scheduledBasalRate
        self.sensitivity = sensitivity
        self.carbRatio = carbRatio
        self.target = target
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.maximumBolus = maximumBolus
        self.suspendThreshold = suspendThreshold
    }
}

extension LoopDosingInput: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.scheduledBasalRate = try container.decode(Double.self, forKey: .scheduledBasalRate)
        let sensitivityMgdl = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .sensitivity)
        self.sensitivity = sensitivityMgdl.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value))}
        self.carbRatio = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .carbRatio)
        let targetMgdl = try container.decode([AbsoluteScheduleValue<DoubleRange>].self, forKey: .target)
        self.target = targetMgdl.map {
            let min = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value.minValue)
            let max = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value.minValue)
            return AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: ClosedRange(uncheckedBounds: (lower: min, upper: max)))
        }
        self.maximumBasalRatePerHour = try container.decodeIfPresent(Double.self, forKey: .maximumBasalRatePerHour)
        self.maximumBolus = try container.decode(Double.self, forKey: .maximumBolus)
        self.suspendThreshold = try container.decode(GlucoseThreshold.self, forKey: .suspendThreshold)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(scheduledBasalRate, forKey: .scheduledBasalRate)
        let sensitivityMgdl = sensitivity.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: $0.value.doubleValue(for: .milligramsPerDeciliter)) }
        try container.encode(sensitivityMgdl, forKey: .sensitivity)
        try container.encode(carbRatio, forKey: .carbRatio)
        let targetMgdl = target.map {
            let min = $0.value.lowerBound.doubleValue(for: .milligramsPerDeciliter)
            let max = $0.value.upperBound.doubleValue(for: .milligramsPerDeciliter)
            return AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: DoubleRange(minValue: min, maxValue: max))
        }
        try container.encode(targetMgdl, forKey: .target)
        try container.encode(maximumBasalRatePerHour, forKey: .maximumBasalRatePerHour)
        try container.encode(maximumBolus, forKey: .maximumBolus)
        try container.encode(suspendThreshold, forKey: .suspendThreshold)
    }

    private enum CodingKeys: String, CodingKey {
        case scheduledBasalRate
        case sensitivity
        case carbRatio
        case target
        case maximumBasalRatePerHour
        case maximumBolus
        case suspendThreshold
    }
}

extension LoopDosingInput {

    var simplifiedForFixture: LoopDosingInput {
        return LoopDosingInput(
            scheduledBasalRate: scheduledBasalRate,
            sensitivity: sensitivity,
            carbRatio: carbRatio,
            target: target,
            maximumBolus: maximumBolus,
            suspendThreshold: suspendThreshold
        )
    }
}
