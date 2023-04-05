//
//  GlucoseSchedule.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/12/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit

public typealias InsulinSensitivitySchedule = SingleQuantitySchedule

public extension InsulinSensitivitySchedule {
    private func convertTo(unit: HKUnit) -> InsulinSensitivitySchedule? {
        guard unit != self.unit else {
            return self
        }

        let convertedDailyItems: [RepeatingScheduleValue<Double>] = self.items.map {
            RepeatingScheduleValue(startTime: $0.startTime,
                                   value: HKQuantity(unit: self.unit, doubleValue: $0.value).doubleValue(for: unit)
            )
        }

        return InsulinSensitivitySchedule(unit: unit,
                                          dailyItems: convertedDailyItems,
                                          timeZone: timeZone)
    }

    func schedule(for glucoseUnit: HKUnit) -> InsulinSensitivitySchedule? {
        // InsulinSensitivitySchedule stores only the glucose unit.
        precondition(glucoseUnit == .millimolesPerLiter || glucoseUnit == .milligramsPerDeciliter)
        return self.convertTo(unit: glucoseUnit)
    }
}
