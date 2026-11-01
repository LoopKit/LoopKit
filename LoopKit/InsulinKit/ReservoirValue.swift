//
//  ReservoirValue.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CoreData


public protocol ReservoirValue: TimelineValue {
    var startDate: Date { get }
    var unitVolume: Double { get }
}


struct StoredReservoirValue: ReservoirValue {
    let startDate: Date
    let unitVolume: Double
    let objectIDURL: URL
}


extension Reservoir: ReservoirValue {
    var startDate: Date {
        return date
    }

    var unitVolume: Double {
        return volume
    }

    var storedReservoirValue: StoredReservoirValue {
        return StoredReservoirValue(startDate: startDate, unitVolume: unitVolume, objectIDURL: objectID.uriRepresentation())
    }
}
