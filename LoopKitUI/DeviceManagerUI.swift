//
//  DeviceManagerUI.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 6/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

public protocol DeviceManagerUI: DeviceManager {
    /// An image representing a device configuration after it is set up
    var smallImage: UIImage? { get }
}
