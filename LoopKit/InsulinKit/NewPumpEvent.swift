//
//  NewPumpEvent.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public struct NewPumpEvent: Equatable {
    /// The date of the event
    public let date: Date
    /// The insulin dose described by the event, if applicable
    public let dose: DoseEntry?
    /// The opaque raw data representing the event
    public let raw: Data
    /// The type of pump event
    public let type: PumpEventType?
    /// A human-readable title to describe the event
    public let title: String
    /// The type of alarm, only valid if type == .alarm
    public let alarmType: PumpAlarmType?

    public init(date: Date, dose: DoseEntry?, raw: Data, title: String, type: PumpEventType? = nil, alarmType: PumpAlarmType? = nil) {
        self.date = date
        self.raw = raw
        self.title = title

        var dose = dose
        // Use the raw data as the unique identifier for the dose
        dose?.syncIdentifier = raw.hexadecimalString
        self.dose = dose

        // Try to use the dose's type if no explicit type was set
        self.type = type ?? dose?.type.pumpEventType

        self.alarmType = alarmType
    }
}

extension NewPumpEvent: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: [String: Any]) {
        guard let date = rawValue["date"] as? Date,
              let raw = rawValue["raw"] as? Data,
              let title = rawValue["title"] as? String
        else {
            return nil
        }

        self.date = date
        self.raw = raw
        self.title = title

        self.dose = (rawValue["dose"] as? DoseEntry.RawValue).flatMap { DoseEntry(rawValue: $0) }
        self.type = (rawValue["type"] as? PumpEventType.RawValue).flatMap { PumpEventType(rawValue: $0) }
        self.alarmType = (rawValue["alarmType"] as? PumpAlarmType.RawValue).flatMap { PumpAlarmType(rawValue: $0) }
    }

    public var rawValue: [String: Any] {
        var rawValue: [String: Any] = [
            "date": date,
            "raw": raw,
            "title": title
        ]

        rawValue["dose"] = dose?.rawValue
        rawValue["type"] = type?.rawValue
        rawValue["alarmType"] = alarmType?.rawValue

        return rawValue
    }
}
