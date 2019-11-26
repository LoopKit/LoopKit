//
//  Settings.swift
//  LoopKit
//
//  Created by Darin Krauss on 9/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit

public protocol Settings {

    var dosingEnabled: Bool { get }

    var glucoseTargetRangeSchedule: GlucoseRangeSchedule? { get }

    var preMealTargetRange: DoubleRange? { get }

    var overridePresets: [TemporaryScheduleOverridePreset] { get }

    var scheduleOverride: TemporaryScheduleOverride? { get }

    var maximumBasalRatePerHour: Double? { get }

    var maximumBolus: Double? { get }

    var suspendThreshold: GlucoseThreshold? { get }

    var glucoseUnit: HKUnit? { get }

    var insulinModel: InsulinModel? { get }

    var basalRateSchedule: BasalRateSchedule? { get }

    var insulinSensitivitySchedule: InsulinSensitivitySchedule? { get }

    var carbRatioSchedule: CarbRatioSchedule? { get }

}
