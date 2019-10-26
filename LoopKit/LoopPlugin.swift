//
//  LoopPlugin.swift
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
}

public protocol LoopPlugin {
    var pumpManagerType: PumpManager.Type? { get }
    var cgmManagerType: CGMManager.Type? { get }
}
