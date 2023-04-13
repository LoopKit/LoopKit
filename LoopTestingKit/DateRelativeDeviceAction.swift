//
//  DateRelativeDeviceAction.swift
//  LoopTestingKit
//
//  Created by Cameron Ingham on 4/12/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import LoopKit


struct DateRelativeDeviceAction: DateRelativeQuantity, Codable {
    var name: String
    var dateOffset: TimeInterval
    
    func newDeviceAction(relativeTo referenceDate: Date) -> NewDeviceAction {
        NewDeviceAction(
            name: name,
            date: referenceDate.addingTimeInterval(dateOffset)
        )
    }
    
    enum CodingKeys: String, CodingKey {
        case name = "action"
        case dateOffset
    }
}
