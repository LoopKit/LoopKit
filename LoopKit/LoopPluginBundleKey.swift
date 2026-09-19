//
//  LoopPluginBundleKey.swift
//  LoopKit
//
//  Created by Pete Schwamb on 7/24/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public enum LoopPluginBundleKey: String {
    case cgmManagerDisplayName = "com.loopkit.Loop.CGMManagerDisplayName"
    case cgmManagerIdentifier = "com.loopkit.Loop.CGMManagerIdentifier"
    case extensionIdentifier = "com.loopkit.Loop.ExtensionIdentifier"
    case onboardingIdentifier = "com.loopkit.Loop.OnboardingIdentifier"
    case pluginIsSimulator = "com.loopkit.Loop.PluginIsSimulator"
    case pumpManagerDisplayName = "com.loopkit.Loop.PumpManagerDisplayName"
    case pumpManagerIdentifier = "com.loopkit.Loop.PumpManagerIdentifier"
    case serviceDisplayName = "com.loopkit.Loop.ServiceDisplayName"
    case serviceIdentifier = "com.loopkit.Loop.ServiceIdentifier"
    case statefulPluginIdentifier = "com.loopkit.Loop.StatefulPluginIdentifier"
    case supportIdentifier = "com.loopkit.Loop.SupportIdentifier"
    case deviceManufacturer = "com.loopkit.Loop.DeviceManufacturer"
    case serviceCategory = "com.loopkit.Loop.ServiceCategory"
}
