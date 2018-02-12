//
//  PersistedPumpEvent.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import CoreData
import Foundation


public struct PersistedPumpEvent {
    /// The date of the event
    public let date: Date
    /// The insulin dose described by the event, if applicable
    public let dose: DoseEntry?
    /// Whether the event has been successfully uploaded
    public let isUploaded: Bool
    /// The internal identifier of the event used by the store
    /// TODO: This should be just the URI representation
    public let objectID: NSManagedObjectID
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
            dose: dose,
            isUploaded: isUploaded,
            objectID: objectID,
            raw: raw,
            title: title,
            type: type
        )
    }
}
