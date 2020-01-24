//
//  DeviceLogEntry+CoreDataClass.swift
//  LoopKit
//
//  Created by Pete Schwamb on 1/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData

class DeviceLogEntry: NSManagedObject {

    var type: DeviceLogEntryType? {
        get {
            willAccessValue(forKey: "type")
            defer { didAccessValue(forKey: "type") }
            return DeviceLogEntryType(rawValue: primitiveType ?? "")
        }
        set {
            willChangeValue(forKey: "type")
            defer { didChangeValue(forKey: "type") }
            primitiveType = newValue?.rawValue
        }
    }

}
