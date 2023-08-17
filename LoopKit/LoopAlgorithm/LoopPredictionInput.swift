//
//  LoopAlgorithmInput.swift
//  Learn
//
//  Created by Pete Schwamb on 7/29/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct LoopAlgorithmSettings {
    var basal: [AbsoluteScheduleValue<Double>]
    var sensitivity: [AbsoluteScheduleValue<HKQuantity>]
    var carbRatio: [AbsoluteScheduleValue<Double>]
    var target: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>]
    var delta: TimeInterval
    var insulinActivityDuration: TimeInterval
    public var algorithmEffectsOptions: AlgorithmEffectsOptions
    var maximumBasalRatePerHour: Double? = nil
    var maximumBolus: Double? = nil
    var suspendThreshold: GlucoseThreshold? = nil

    public init(
        basal: [AbsoluteScheduleValue<Double>],
        sensitivity: [AbsoluteScheduleValue<HKQuantity>],
        carbRatio: [AbsoluteScheduleValue<Double>],
        target: [AbsoluteScheduleValue<ClosedRange<HKQuantity>>],
        delta: TimeInterval = GlucoseMath.defaultDelta,
        insulinActivityDuration: TimeInterval = InsulinMath.defaultInsulinActivityDuration,
        algorithmEffectsOptions: AlgorithmEffectsOptions = .all,
        maximumBasalRatePerHour: Double? = nil,
        maximumBolus: Double? = nil,
        suspendThreshold: GlucoseThreshold? = nil)
    {
        self.basal = basal
        self.sensitivity = sensitivity
        self.carbRatio = carbRatio
        self.target = target
        self.delta = delta
        self.insulinActivityDuration = insulinActivityDuration
        self.algorithmEffectsOptions = algorithmEffectsOptions
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.maximumBolus = maximumBolus
        self.suspendThreshold = suspendThreshold
    }
}

extension LoopAlgorithmSettings: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.basal = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .basal)
        let sensitivityMgdl = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .sensitivity)
        self.sensitivity = sensitivityMgdl.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value))}
        self.carbRatio = try container.decode([AbsoluteScheduleValue<Double>].self, forKey: .carbRatio)
        let targetMgdl = try container.decode([AbsoluteScheduleValue<DoubleRange>].self, forKey: .target)
        self.target = targetMgdl.map {
            let min = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value.minValue)
            let max = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: $0.value.minValue)
            return AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: ClosedRange(uncheckedBounds: (lower: min, upper: max)))
        }
        self.delta = TimeInterval(minutes: 5)
        self.insulinActivityDuration = InsulinMath.defaultInsulinActivityDuration
        self.algorithmEffectsOptions = .all
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(basal, forKey: .basal)
        let sensitivityMgdl = sensitivity.map { AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: $0.value.doubleValue(for: .milligramsPerDeciliter)) }
        try container.encode(sensitivityMgdl, forKey: .sensitivity)
        try container.encode(carbRatio, forKey: .carbRatio)
        let targetMgdl = target.map {
            let min = $0.value.lowerBound.doubleValue(for: .milligramsPerDeciliter)
            let max = $0.value.upperBound.doubleValue(for: .milligramsPerDeciliter)
            return AbsoluteScheduleValue(startDate: $0.startDate, endDate: $0.endDate, value: DoubleRange(minValue: min, maxValue: max))
        }
        try container.encode(targetMgdl, forKey: .target)
    }

    private enum CodingKeys: String, CodingKey {
        case basal
        case sensitivity
        case carbRatio
        case target
        case delta
        case insulinActivityDuration
        case algorithmEffectsOptions
    }
}

extension LoopAlgorithmSettings {

    var simplifiedForFixture: LoopAlgorithmSettings {
        return LoopAlgorithmSettings(
            basal: basal,
            sensitivity: sensitivity,
            carbRatio: carbRatio,
            target: target)
    }
}


public struct LoopPredictionInput: GlucosePredictionInput {
    public var glucoseHistory: [StoredGlucoseSample]
    public var doses: [DoseEntry]
    public var carbEntries: [StoredCarbEntry]
    public var settings: LoopAlgorithmSettings

    public init(
        glucoseHistory: [StoredGlucoseSample],
        doses: [DoseEntry],
        carbEntries: [StoredCarbEntry],
        settings: LoopAlgorithmSettings)
    {
        self.glucoseHistory = glucoseHistory
        self.doses = doses
        self.carbEntries = carbEntries
        self.settings = settings
    }
}


extension LoopPredictionInput: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.glucoseHistory = try container.decode([StoredGlucoseSample].self, forKey: .glucoseHistory)
        self.doses = try container.decode([DoseEntry].self, forKey: .doses)
        self.carbEntries = try container.decode([StoredCarbEntry].self, forKey: .carbEntries)
        self.settings = try container.decode(LoopAlgorithmSettings.self, forKey: .settings)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(glucoseHistory, forKey: .glucoseHistory)
        try container.encode(doses, forKey: .doses)
        try container.encode(carbEntries, forKey: .carbEntries)
        try container.encode(settings, forKey: .settings)
    }

    private enum CodingKeys: String, CodingKey {
        case glucoseHistory
        case doses
        case carbEntries
        case settings
    }
}

extension LoopPredictionInput {

    var simplifiedForFixture: LoopPredictionInput {
        return LoopPredictionInput(
            glucoseHistory: glucoseHistory.map {
                StoredGlucoseSample(startDate: $0.startDate, quantity: $0.quantity)
            },
            doses: doses.map {
                DoseEntry(type: $0.type, startDate: $0.startDate, value: $0.value, unit: $0.unit)
            },
            carbEntries: carbEntries.map {
                StoredCarbEntry(startDate: $0.startDate, quantity: $0.quantity)
            },
            settings: settings.simplifiedForFixture
        )
    }

    public func printFixture() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(self.simplifiedForFixture),
           let json = String(data: data, encoding: .utf8)
        {
            print(json)
        }
    }
}
