//
//  EGPSchedule.swift
//  LoopKit
//
//  Created by Michael Pangburn on 3/27/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

public typealias EGPSchedule = SingleQuantitySchedule

extension /* EGPSchedule */ DailyQuantitySchedule where T == Double {
    public static func egpSchedule(basalSchedule: BasalRateSchedule, insulinSensitivitySchedule: InsulinSensitivitySchedule) -> EGPSchedule {
        let basalScheduleWithUnit = DailyQuantitySchedule(unit: .internationalUnitsPerHour, valueSchedule: basalSchedule)
        return basalScheduleWithUnit * insulinSensitivitySchedule
    }
}
