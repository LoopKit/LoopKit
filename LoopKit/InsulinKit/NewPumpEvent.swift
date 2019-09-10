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
    /// Whether the dose value is expected to change.
    public let isMutable: Bool
    /// The opaque raw data representing the event
    public let raw: Data
    /// The type of pump event
    public let type: PumpEventType?
    /// A human-readable title to describe the event
    public let title: String

    public init(date: Date, dose: DoseEntry?, isMutable: Bool, raw: Data, title: String, type: PumpEventType? = nil) {
        self.date = date
        self.isMutable = isMutable
        self.raw = raw
        self.title = title

        var dose = dose
        // Use the raw data as the unique identifier for the dose
        dose?.syncIdentifier = raw.hexadecimalString
        self.dose = dose

        // Try to use the dose's type if no explicit type was set
        self.type = type ?? dose?.type.pumpEventType
    }
}
