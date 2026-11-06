//
//  DeviceManagerPlugin.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation

/// As LoopKitUI's `PumpManagerUIPlugin`, for a host without LoopKitUI (the watch): the bundle's principal
/// class conforms, and its Info.plist names the manager (`LoopPluginBundleKey.pumpManagerIdentifier`).
public protocol PumpManagerPlugin {
    var pumpManagerType: PumpManager.Type? { get }
}

/// As LoopKitUI's `CGMManagerUIPlugin`, for a host without LoopKitUI (`LoopPluginBundleKey.cgmManagerIdentifier`).
public protocol CGMManagerPlugin {
    var cgmManagerType: CGMManager.Type? { get }
}

/// What a CGM the watch reads directly tells the watch app beyond `CGMManager`.
public protocol DirectReadCGMManager: CGMManager {
    /// On a wake that is not the CGM's own, its acquisition re-checks itself: a lost Bluetooth
    /// callback can leave no connect standing and nothing to notice.
    func recheckAcquisition()

    /// Searching for its sensor, which needs the app kept open.
    var isSearchingForSensor: Bool { get }

    /// What the CGM needs from the user (a code, or the app kept open while it searches); nil for nothing.
    var directReadStatusNote: String? { get }

    var sensorName: String? { get }

    /// When the watch last had a link to the sensor, readings or not.
    var lastConnect: Date? { get }
}

public extension Notification.Name {
    /// Posted by a `DirectReadCGMManager` when its search or status note changes; the object is the manager.
    static let directReadCGMStatusDidChange = Notification.Name("com.loopkit.DirectReadCGMStatusDidChange")
}
