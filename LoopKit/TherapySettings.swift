//
//  TherapySettings.swift
//  LoopKit
//
//  Created by Anna Quinlan on 7/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct TherapySettings: Equatable {

    public var glucoseTargetRangeSchedule: GlucoseRangeSchedule?

    public var correctionRangeOverrides: CorrectionRangeOverrides?

    public var overridePresets: [TemporaryScheduleOverridePreset]?

    public var maximumBasalRatePerHour: Double?

    public var maximumBolus: Double?

    public var suspendThreshold: GlucoseThreshold?

    public var insulinSensitivitySchedule: InsulinSensitivitySchedule?

    public var carbRatioSchedule: CarbRatioSchedule?
    
    public var basalRateSchedule: BasalRateSchedule?
    
    public var defaultRapidActingModel: ExponentialInsulinModelPreset?

    public var isComplete: Bool {
        return
            glucoseTargetRangeSchedule != nil &&
            /* Correction Range (Premeal and workout) targets are optional */
            // correctionRangeOverrides != nil &&
            maximumBasalRatePerHour != nil &&
            maximumBolus != nil &&
            suspendThreshold != nil &&
            insulinSensitivitySchedule != nil &&
            carbRatioSchedule != nil &&
            basalRateSchedule != nil
    }
    
    public init(
        glucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
        correctionRangeOverrides: CorrectionRangeOverrides? = nil,
        overridePresets: [TemporaryScheduleOverridePreset]? = nil,
        maximumBasalRatePerHour: Double? = nil,
        maximumBolus: Double? = nil,
        suspendThreshold: GlucoseThreshold? = nil,
        insulinSensitivitySchedule: InsulinSensitivitySchedule? = nil,
        carbRatioSchedule: CarbRatioSchedule? = nil,
        basalRateSchedule: BasalRateSchedule? = nil,
        defaultRapidActingModel: ExponentialInsulinModelPreset? = nil
    ){
        self.glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        self.correctionRangeOverrides = correctionRangeOverrides
        self.overridePresets = overridePresets
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.maximumBolus = maximumBolus
        self.suspendThreshold = suspendThreshold
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
        self.carbRatioSchedule = carbRatioSchedule
        self.basalRateSchedule = basalRateSchedule
        self.defaultRapidActingModel = defaultRapidActingModel
    }
}

extension TherapySettings: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let glucoseTargetRangeSchedule = try container.decodeIfPresent(GlucoseRangeSchedule.self, forKey: .glucoseTargetRangeSchedule)
        let correctionRangeOverrides = try container.decodeIfPresent(CorrectionRangeOverrides.self, forKey: .correctionRangeOverrides)
        let maximumBasalRatePerHour = try container.decodeIfPresent(Double.self, forKey: .maximumBasalRatePerHour)
        let maximumBolus = try container.decodeIfPresent(Double.self, forKey: .maximumBolus)
        let suspendThreshold = try container.decodeIfPresent(GlucoseThreshold.self, forKey: .suspendThreshold)
        let insulinSensitivitySchedule = try container.decodeIfPresent(InsulinSensitivitySchedule.self, forKey: .insulinSensitivitySchedule)
        let carbRatioSchedule = try container.decodeIfPresent(CarbRatioSchedule.self, forKey: .carbRatioSchedule)
        let basalRateSchedule = try container.decodeIfPresent(BasalRateSchedule.self, forKey: .basalRateSchedule)
        let defaultRapidActingModel = try container.decodeIfPresent(ExponentialInsulinModelPreset.self, forKey: .defaultRapidActingModel)

        self.init(glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
                  correctionRangeOverrides: correctionRangeOverrides,
                  maximumBasalRatePerHour: maximumBasalRatePerHour,
                  maximumBolus: maximumBolus,
                  suspendThreshold: suspendThreshold,
                  insulinSensitivitySchedule: insulinSensitivitySchedule,
                  carbRatioSchedule: carbRatioSchedule,
                  basalRateSchedule: basalRateSchedule,
                  defaultRapidActingModel: defaultRapidActingModel)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(glucoseTargetRangeSchedule, forKey: .glucoseTargetRangeSchedule)
        try container.encodeIfPresent(correctionRangeOverrides, forKey: .correctionRangeOverrides)
        try container.encodeIfPresent(maximumBasalRatePerHour, forKey: .maximumBasalRatePerHour)
        try container.encodeIfPresent(maximumBolus, forKey: .maximumBolus)
        try container.encodeIfPresent(suspendThreshold, forKey: .suspendThreshold)
        try container.encodeIfPresent(insulinSensitivitySchedule, forKey: .insulinSensitivitySchedule)
        try container.encodeIfPresent(carbRatioSchedule, forKey: .carbRatioSchedule)
        try container.encodeIfPresent(basalRateSchedule, forKey: .basalRateSchedule)
        try container.encodeIfPresent(defaultRapidActingModel, forKey: .defaultRapidActingModel)
    }

    private enum CodingKeys: String, CodingKey {
        case glucoseTargetRangeSchedule
        case correctionRangeOverrides
        case maximumBasalRatePerHour
        case maximumBolus
        case suspendThreshold
        case insulinSensitivitySchedule
        case carbRatioSchedule
        case basalRateSchedule
        case defaultRapidActingModel
    }
}

extension TherapySettings {
    // Mock therapy settings for QA and mock prescriptions
    public static var mockTherapySettings: TherapySettings {
        let timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let glucoseTargetRangeSchedule =  GlucoseRangeSchedule(
            rangeSchedule: DailyQuantitySchedule(unit: .milligramsPerDeciliter,
                dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: DoubleRange(minValue: 100.0, maxValue: 110.0)),
                             RepeatingScheduleValue(startTime: .hours(8), value: DoubleRange(minValue: 105.0, maxValue: 115.0)),
                             RepeatingScheduleValue(startTime: .hours(21), value: DoubleRange(minValue: 100.0, maxValue: 110.0))],
                timeZone: timeZone)!,
            override: GlucoseRangeSchedule.Override(value: DoubleRange(minValue: 80.0, maxValue: 90.0),
                                                    start: Date().addingTimeInterval(.minutes(-30)),
                                                    end: Date().addingTimeInterval(.minutes(30)))
        )
        let correctionRangeOverrides = CorrectionRangeOverrides(preMeal: DoubleRange(minValue: 80.0, maxValue: 90.0),
                                                                workout: DoubleRange(minValue: 140.0, maxValue: 160.0),
                                                                unit: .milligramsPerDeciliter)
        let basalRateSchedule = BasalRateSchedule(
            dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 1),
                         RepeatingScheduleValue(startTime: .hours(15), value: 0.85)],
            timeZone: timeZone)!
        let insulinSensitivitySchedule = InsulinSensitivitySchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 45.0),
                         RepeatingScheduleValue(startTime: .hours(9), value: 55.0)],
            timeZone: timeZone)!
        let carbRatioSchedule = CarbRatioSchedule(
            unit: .gram(),
            dailyItems: [RepeatingScheduleValue(startTime: .hours(0), value: 10.0)],
            timeZone: timeZone)!
        return TherapySettings(
            glucoseTargetRangeSchedule: glucoseTargetRangeSchedule,
            correctionRangeOverrides: correctionRangeOverrides,
            maximumBasalRatePerHour: 5,
            maximumBolus: 10,
            suspendThreshold: GlucoseThreshold(unit: .milligramsPerDeciliter, value: 75),
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            carbRatioSchedule: carbRatioSchedule,
            basalRateSchedule: basalRateSchedule,
            defaultRapidActingModel: .rapidActingAdult
        )
    }
}
