//
//  DeviceStatusBadge.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2021-02-16.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import UIKit

public protocol DeviceStatusBadge {
    
    /// the image to present as the badge
    var image: UIImage? { get }
    
    /// the state of the status badge (guides presentation)
    var state: DeviceStatusBadgeState { get }
}

public typealias DeviceStatusBadgeState = DeviceStatusElementState
