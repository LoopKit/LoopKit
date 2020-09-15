//
//  DeviceLogEntry+CoreDataProperties.swift
//  LoopKit
//
//  Created by Pete Schwamb on 1/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//
//

import Foundation
import CoreData


extension DeviceLogEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DeviceLogEntry> {
        return NSFetchRequest<DeviceLogEntry>(entityName: "Entry")
    }

    @NSManaged public var primitiveType: String?
    @NSManaged public var managerIdentifier: String?
    @NSManaged public var deviceIdentifier: String?
    @NSManaged public var message: String?
    @NSManaged public var timestamp: Date?

}

extension DeviceLogEntry {
    func update(from entry: StoredDeviceLogEntry) {
        type = entry.type
        managerIdentifier = entry.managerIdentifier
        deviceIdentifier = entry.deviceIdentifier
        message = entry.message
        timestamp = entry.timestamp
    }
}
