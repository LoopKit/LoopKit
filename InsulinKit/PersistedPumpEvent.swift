//
//  PersistedPumpEvent.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import CoreData
import Foundation


public protocol PersistedPumpEvent {
    /// The date of the event
    var date: Date! { get }
    /// The insulin dose described by the event, if applicable
    var dose: DoseEntry? { get }
    /// The internal identifier of the event used by the store
    var objectID: NSManagedObjectID { get }
    /// The opaque raw data representing the event
    var raw: Data? { get }
}
