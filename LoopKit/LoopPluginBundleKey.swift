//
//  LoopPluginBundleKey.swift
//  LoopKit
//
//  Created by Pete Schwamb on 7/24/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public enum LoopPluginBundleKey: String {
    case pumpManagerDisplayName = "com.loopkit.Loop.PumpManagerDisplayName"
    case pumpManagerIdentifier = "com.loopkit.Loop.PumpManagerIdentifier"
    case cgmManagerDisplayName = "com.loopkit.Loop.CGMManagerDisplayName"
    case cgmManagerIdentifier = "com.loopkit.Loop.CGMManagerIdentifier"
    case serviceDisplayName = "com.loopkit.Loop.ServiceDisplayName"
    case serviceIdentifier = "com.loopkit.Loop.ServiceIdentifier"
    case extensionIdentifier = "com.loopkit.Loop.ExtensionIdentifier"
    case providesOnboarding = "com.loopkit.Loop.Plugin.ProvidesOnboarding"
}
