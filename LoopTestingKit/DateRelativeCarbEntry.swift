//
//  DateRelativeCarbEntry.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 4/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopAlgorithm
import LoopKit


struct DateRelativeCarbEntry: DateRelativeQuantity, Codable {
    var gramValue: Double
    var dateOffset: TimeInterval
    var enteredAtOffset: TimeInterval?
    var absorptionTime: TimeInterval

    var quantity: LoopQuantity {
        return LoopQuantity(unit: .gram, doubleValue: gramValue)
    }

    func newCarbEntry(relativeTo referenceDate: Date) -> NewCarbEntry {
        let startDate = referenceDate.addingTimeInterval(dateOffset)
        return NewCarbEntry(quantity: quantity, startDate: startDate, foodType: nil, absorptionTime: absorptionTime)
    }

    func enteredAt(relativeTo referenceDate: Date) -> Date {
        return referenceDate.addingTimeInterval(enteredAtOffset ?? dateOffset)
    }
}
