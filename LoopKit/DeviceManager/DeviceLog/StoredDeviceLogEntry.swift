//
//  StoredDeviceLogEntry.swift
//  LoopKit
//
//  Created by Pete Schwamb on 1/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public struct StoredDeviceLogEntry {
    public let type: DeviceLogEntryType
    public let deviceManager: String
    public let deviceIdentifier: String?
    public let message: String
    public let timestamp: Date
    
    public init(
        type: DeviceLogEntryType,
        deviceManager: String,
        deviceIdentifier: String?,
        message: String,
        timestamp: Date
    ) {
        self.type = type
        self.deviceManager = deviceManager
        self.deviceIdentifier = deviceIdentifier
        self.message = message
        self.timestamp = timestamp
    }

    
    init(managedObject: DeviceLogEntry) {
        self.init(
            type: managedObject.type!,
            deviceManager: managedObject.deviceManager!,
            deviceIdentifier: managedObject.deviceIdentifier,
            message: managedObject.message!,
            timestamp: managedObject.timestamp!
        )
    }
}
