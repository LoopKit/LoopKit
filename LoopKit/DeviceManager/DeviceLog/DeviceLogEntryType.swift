//
//  DeviceLogEntryType.swift
//  LoopKit
//
//  Created by Pete Schwamb on 1/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum DeviceLogEntryType: String {
    /// Log entry related to data or commands sent to the device.
    case send
    /// Log entry related to data or events received from the device.
    case receive
    /// Log entry related to any errors from the device's SDK or the device itself.
    case error
    /// Log entry related to a delegate call from the device's SDK (for example, acknowledgement of receiving a command).
    case delegate
    /// Log entry related to a response from a delegate call (for example, acknowledgement of executing a command).
    case delegateResponse
    /// Log entry related to any device connection activities (e.g. scanning, connecting, disconnecting, reconnecting, etc.).
    case connection
}
