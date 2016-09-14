//
//  NewPumpEvent.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public struct NewPumpEvent {
    /// The date of the event
    public let date: Date
    /// The insulin dose described by the event, if applicable
    public let dose: DoseEntry?
    /// Whether the dose value is expected to change. It will be used for calculation purposes but not persisted.
    public let isMutable: Bool
    /// The opaque raw data representing the event
    public let raw: Data?
    /// A human-readable title to describe the event
    public let title: String

    public init(date: Date, dose: DoseEntry?, isMutable: Bool, raw: Data, title: String) {
        self.date = date
        self.dose = dose
        self.isMutable = isMutable
        self.raw = raw
        self.title = title
    }
}
