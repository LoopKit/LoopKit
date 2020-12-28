//
//  PersistedOutsideDose.swift
//  LoopKit
//
//  Created by Anna Quinlan on 4/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import Foundation

// A wrapper around the CachedInsulinDeliveryObject to allow it to be used for logged/outside doses in Loop
public struct PersistedOutsideDose {
    /// The date of the event
    public let date: Date
    /// The date the event was persisted
    public let persistedDate: Date?
    /// The insulin dose described by the event
    public let dose: DoseEntry?
    /// The event's UUID
    public let uuid: UUID?
}

extension CachedInsulinDeliveryObject {
    var persistedOutsideDose: PersistedOutsideDose? {
        guard provenanceIdentifier == "org.loopkit.provenance.manualEntry" else {
            return nil
        }
        
        return PersistedOutsideDose(
            date: startDate,
            persistedDate: createdAt,
            dose: dose,
            uuid: uuid
        )
    }
}
