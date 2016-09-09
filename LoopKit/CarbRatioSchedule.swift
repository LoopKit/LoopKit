//
//  CarbRatioSchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public class CarbRatioSchedule: SingleQuantitySchedule {
    public override init?(unit: HKUnit, dailyItems: [RepeatingScheduleValue<Double>], timeZone: TimeZone? = nil) {
        super.init(unit: unit, dailyItems: dailyItems, timeZone: timeZone)

        guard unit == HKUnit.gram() else {
            return nil
        }
    }
}
