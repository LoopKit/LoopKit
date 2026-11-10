//
//  DeviceManagerPlugin.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// A device kit's principal class, for a host without LoopKitUI (the watch); LoopKitUI's `PumpManagerUIPlugin`
/// extends it. The bundle's Info.plist names the manager (`LoopPluginBundleKey.pumpManagerIdentifier`).
public protocol PumpManagerPlugin {
    var pumpManagerType: PumpManager.Type? { get }
}

/// As `PumpManagerPlugin`, for a CGM; LoopKitUI's `CGMManagerUIPlugin` extends it (`LoopPluginBundleKey.cgmManagerIdentifier`).
public protocol CGMManagerPlugin {
    var cgmManagerType: CGMManager.Type? { get }
}
