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
    @NSManaged public var modificationCounter: Int64

}

extension DeviceLogEntry: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type?.rawValue, forKey: .type)
        try container.encodeIfPresent(managerIdentifier, forKey: .managerIdentifier)
        try container.encodeIfPresent(deviceIdentifier, forKey: .deviceIdentifier)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encode(modificationCounter, forKey: .modificationCounter)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case managerIdentifier
        case deviceIdentifier
        case message
        case timestamp
        case modificationCounter
    }
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
