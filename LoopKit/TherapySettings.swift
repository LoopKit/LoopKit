//
//  TherapySettings.swift
//  LoopKit
//
//  Created by Anna Quinlan on 7/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct TherapySettings: Equatable, Codable {
    
    public var glucoseTargetRangeSchedule: GlucoseRangeSchedule?

    public var preMealTargetRange: DoubleRange?

    public var workoutTargetRange: DoubleRange?

    public var maximumBasalRatePerHour: Double?

    public var maximumBolus: Double?

    public var suspendThreshold: GlucoseThreshold?
    
    public var insulinSensitivitySchedule: InsulinSensitivitySchedule?
    
    public var carbRatioSchedule: CarbRatioSchedule?
    
    public var basalRateSchedule: BasalRateSchedule?
    
    public var insulinModelSettings: InsulinModelSettings?
    
    public var glucoseUnit: HKUnit? {
        return glucoseTargetRangeSchedule?.unit
    }
    
    public var isComplete: Bool {
        return
            glucoseTargetRangeSchedule != nil &&
            /* Premeal and workout targets are optional */
            //preMealTargetRange != nil &&
            //workoutTargetRange != nil &&
            maximumBasalRatePerHour != nil &&
            maximumBolus != nil &&
            suspendThreshold != nil &&
            insulinSensitivitySchedule != nil &&
            carbRatioSchedule != nil &&
            basalRateSchedule != nil &&
            insulinModelSettings != nil
    }
    
    public init(
        glucoseTargetRangeSchedule: GlucoseRangeSchedule? = nil,
        preMealTargetRange: DoubleRange? = nil,
        workoutTargetRange: DoubleRange? = nil,
        maximumBasalRatePerHour: Double? = nil,
        maximumBolus: Double? = nil,
        suspendThreshold: GlucoseThreshold? = nil,
        insulinSensitivitySchedule: InsulinSensitivitySchedule? = nil,
        carbRatioSchedule: CarbRatioSchedule? = nil,
        basalRateSchedule: BasalRateSchedule? = nil,
        insulinModelSettings: InsulinModelSettings? = nil
    ){
        self.glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        self.preMealTargetRange = preMealTargetRange
        self.workoutTargetRange = workoutTargetRange
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.maximumBolus = maximumBolus
        self.suspendThreshold = suspendThreshold
        self.insulinSensitivitySchedule = insulinSensitivitySchedule
        self.carbRatioSchedule = carbRatioSchedule
        self.basalRateSchedule = basalRateSchedule
        self.insulinModelSettings = insulinModelSettings
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
            preMealTargetRange: DoubleRange(minValue: 80.0, maxValue: 90.0),
            workoutTargetRange: DoubleRange(minValue: 140.0, maxValue: 160.0),
            maximumBasalRatePerHour: 5,
            maximumBolus: 10,
            suspendThreshold: GlucoseThreshold(unit: .milligramsPerDeciliter, value: 75),
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            carbRatioSchedule: carbRatioSchedule,
            basalRateSchedule: basalRateSchedule,
            insulinModelSettings: InsulinModelSettings(model: ExponentialInsulinModelPreset.humalogNovologAdult)
        )
    }
}
