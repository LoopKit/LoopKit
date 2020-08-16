//
//  PersistedOutsideDoseEvent.swift
//  LoopKit
//
//  Created by Anna Quinlan on 4/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import Foundation

public struct PersistedOutsideDoseEvent {
    /// The date of the event
    public let date: Date
    /// The date the event was persisted
    public let persistedDate: Date
    /// The insulin dose described by the event
    public let dose: DoseEntry?
    /// Whether the event has been successfully uploaded to external sources (Nightscout, etc)
    public let isUploaded: Bool
    /// The NSManagedObject identifier of the event used by the store
    public let objectIDURL: URL
    /// The opaque raw data representing the event
    public let raw: Data?
    /// A human-readable short description of the event
    public let title: String?
    /// Whether the event is marked mutable
    public let isMutable: Bool
}

extension OutsideDoseEvent {
    var persistedOutsideDoseEvent: PersistedOutsideDoseEvent {
        return PersistedOutsideDoseEvent(
            date: date,
            persistedDate: createdAt,
            dose: dose,
            isUploaded: isUploaded,
            objectIDURL: objectID.uriRepresentation(),
            raw: raw,
            title: title,
            isMutable: mutable
        )
    }
}
