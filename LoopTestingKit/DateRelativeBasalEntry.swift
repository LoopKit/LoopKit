//
//  DateRelativeBasalEntry.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 4/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit


struct DateRelativeBasalEntry: DateRelativeQuantity, Codable {
    var unitsPerHourValue: Double
    var dateOffset: TimeInterval
    var duration: TimeInterval

    func doseEntry(relativeTo referenceDate: Date) -> DoseEntry {
        let startDate = referenceDate.addingTimeInterval(dateOffset)
        let endDate = startDate.addingTimeInterval(duration)
        return DoseEntry(type: .tempBasal, startDate: startDate, endDate: endDate, value: unitsPerHourValue, unit: .unitsPerHour)
    }

    func newPumpEvent(relativeTo referenceDate: Date) -> NewPumpEvent {
        let dose = doseEntry(relativeTo: referenceDate)
        return NewPumpEvent(date: dose.startDate, dose: dose, raw: .newPumpEventIdentifier(), title: "Basal", type: .tempBasal)
    }
}
