//
//  PersistedManualEntryDose.swift
//  LoopKit
//
//  Created by Anna Quinlan on 4/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
import Foundation

public struct PersistedManualEntryDose {
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
    var persistedManualEntryDose: PersistedManualEntryDose? {
        guard provenanceIdentifier == "org.loopkit.provenance.manualEntry" else {
            return nil
        }
        
        return PersistedManualEntryDose(
            date: startDate,
            persistedDate: createdAt,
            dose: dose,
            uuid: uuid
        )
    }
}
