//
//  PersistedPumpEvent.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public struct PersistedPumpEvent {
    /// The date of the event
    public let date: Date
    /// The date the event was persisted
    public let persistedDate: Date
    /// The insulin dose described by the event, if applicable
    public let dose: DoseEntry?
    /// Whether the event has been successfully uploaded
    public let isUploaded: Bool
    /// The NSManagedObject identifier of the event used by the store
    public let objectIDURL: URL
    /// The opaque raw data representing the event
    public let raw: Data?
    /// A human-readable short description of the event
    public let title: String?
    /// The type of pump event
    public let type: PumpEventType?
}


extension PumpEvent {
    var persistedPumpEvent: PersistedPumpEvent {
        return PersistedPumpEvent(
            date: date,
            persistedDate: createdAt,
            dose: dose,
            isUploaded: isUploaded,
            objectIDURL: objectID.uriRepresentation(),
            raw: raw,
            title: title,
            type: type
        )
    }
}
