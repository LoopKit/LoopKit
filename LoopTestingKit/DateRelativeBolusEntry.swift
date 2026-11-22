//
//  DateRelativeBolusEntry.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 4/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import Foundation

struct DateRelativeBolusEntry: DateRelativeQuantity, Codable {
    var unitsValue: Double
    var dateOffset: TimeInterval
    var deliveryDuration: TimeInterval

    func doseEntry(relativeTo referenceDate: Date) -> DoseEntry {
        let startDate = referenceDate.addingTimeInterval(dateOffset)
        let endDate = startDate.addingTimeInterval(deliveryDuration)
        return DoseEntry(type: .bolus, startDate: startDate, endDate: endDate, value: unitsValue, unit: .units)
    }

    func newPumpEvent(relativeTo referenceDate: Date) -> NewPumpEvent {
        let dose = doseEntry(relativeTo: referenceDate)
        return NewPumpEvent(date: dose.startDate, dose: dose, raw: .newPumpEventIdentifier(), title: "Bolus", type: .bolus)
    }
}
