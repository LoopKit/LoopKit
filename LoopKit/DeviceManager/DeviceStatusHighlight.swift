//
//  DeviceStatusHighlight.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-23.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

public protocol DeviceStatusHighlight {
    /// a localized message from the device
    var localizedMessage: String { get }

    /// the system name of the icon related to the message
    var imageSystemName: String { get }
        
    /// the state of the status highlight (guides presentation)
    var state: DeviceStatusHighlightState { get }
}

public enum DeviceStatusHighlightState: String, Codable {
    case normal
    case warning
    case critical
}

