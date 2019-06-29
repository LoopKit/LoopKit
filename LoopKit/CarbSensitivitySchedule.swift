//
//  CarbSensitivitySchedule.swift
//  LoopKit
//
//  Created by Michael Pangburn on 3/27/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

public typealias CarbSensitivitySchedule = SingleQuantitySchedule

extension /* CarbSensitivitySchedule */ DailyQuantitySchedule where T == Double {
    public static func carbSensitivitySchedule(insulinSensitivitySchedule: InsulinSensitivitySchedule, carbRatioSchedule: CarbRatioSchedule) -> CarbSensitivitySchedule {
        return insulinSensitivitySchedule / carbRatioSchedule
    }
}
