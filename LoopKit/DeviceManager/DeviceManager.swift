//
//  DeviceManager.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import UserNotifications

public protocol DeviceManagerDelegate: AlertIssuer, PersistedAlertStore {
    // This will be called from an unspecified queue
    func deviceManager(_ manager: DeviceManager, logEventForDeviceIdentifier deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)?)

    /// An `ExclusiveDeviceControl` device's link is up and the device has answered. Optional.
    func deviceManagerControlDidBecomeReady(_ manager: DeviceManager)

    /// Records an event with the app's analytics services. This will be called from an unspecified queue
    func deviceManager(_ manager: DeviceManager, recordAnalyticsEvent name: String, properties: [AnyHashable: Any]?)
}

public extension DeviceManagerDelegate {
    func deviceManager(_ manager: DeviceManager, recordAnalyticsEvent name: String, properties: [AnyHashable: Any]?) {}
}

public protocol DeviceManager: CustomDebugStringConvertible, AlertResponder, AlertSoundVendor, Pluggable {
    typealias RawStateValue = [String: Any]
    
    /// A title describing this manager
    var localizedTitle: String { get }

    /// Initializes the manager with its previously-saved state
    ///
    /// Return nil if the saved state is invalid to prevent restoration
    ///
    /// - Parameter rawState: The last state
    init?(rawState: RawStateValue)

    /// The current, serializable state of the manager
    var rawState: RawStateValue { get }

    /// Is the device manager onboarded and ready for use?
    var isOnboarded: Bool { get }
    
    /// Is the device in a state of signal loss (prolonged communication loss)
    var inSignalLoss: Bool { get }
    
    /// Is the device inoperable (e.g., in a failure state, expired, etc.)
    var isInoperable: Bool { get }

    /// Why the device is inoperable, rendered by the kit for display (e.g. its fault alarm's
    /// title). Default: nil.
    var localizedInoperableDescription: String? { get }
}

public extension DeviceManager {
    var localizedInoperableDescription: String? { nil }
}

// MARK: - Sharing a device with another controller

/// What another controller needs to use a device or service, plus a header the host can read.
public struct SharedDeviceConfiguration: RawRepresentable {
    public typealias RawValue = [String: Any]

    /// Which plugin builds from it: the exporter's `pluginIdentifier`.
    public let managerIdentifier: String
    /// When it was true.
    public let asOf: Date
    /// Pumps: the last known delivered total at `asOf`.
    public let deliveredUnits: Double?
    /// Opaque: only the kit reads it.
    public let state: [String: Any]

    public init(managerIdentifier: String, asOf: Date, deliveredUnits: Double? = nil, state: [String: Any]) {
        self.managerIdentifier = managerIdentifier
        self.asOf = asOf
        self.deliveredUnits = deliveredUnits
        self.state = state
    }

    public init?(rawValue: RawValue) {
        guard let managerIdentifier = rawValue["managerIdentifier"] as? String,
              let asOf = rawValue["asOf"] as? Date,
              let state = rawValue["state"] as? [String: Any] else {
            return nil
        }
        self.init(managerIdentifier: managerIdentifier, asOf: asOf,
                  deliveredUnits: rawValue["deliveredUnits"] as? Double, state: state)
    }

    public var rawValue: RawValue {
        var raw: RawValue = ["managerIdentifier": managerIdentifier, "asOf": asOf, "state": state]
        raw["deliveredUnits"] = deliveredUnits
        return raw
    }
}

/// A device manager or service that can export what another controller needs and be built from
/// such an export. Plugins that cannot simply don't conform; callers find it by conditional cast.
public protocol DeviceConfigurationSharing: Pluggable {
    /// Export for another controller. The kit leaves out what is local to this controller.
    func exportConfiguration() -> SharedDeviceConfiguration

    /// Build a manager from another controller's export ("passed the configuration"), with the
    /// `localState` an earlier manager of this plugin left here.
    init?(adopting configuration: SharedDeviceConfiguration, localState: [String: Any]?)

    /// What this controller learned about the device that is its own (for example its Bluetooth
    /// handle): never in the export, and it should outlive this manager. The host keeps the latest
    /// value per `pluginIdentifier` (an export's `managerIdentifier`) and passes it to the next
    /// `init(adopting:localState:)`. Default: nil.
    var localState: [String: Any]? { get }

    /// Whether the user wants this device shared with another controller (for example a watch reading
    /// a CGM itself). The host exports only while it is true. Default: true.
    var isConfigurationSharingEnabled: Bool { get }
}

public extension DeviceConfigurationSharing {
    var localState: [String: Any]? { nil }
    var isConfigurationSharingEnabled: Bool { true }
}

/// A device whose hardware allows one controller at a time. Release, take and readiness say
/// nothing about who the controllers are; that is the host's business.
public protocol ExclusiveDeviceControl: DeviceConfigurationSharing, DeviceManager {
    /// True while control is released. Persisted by the kit, so a relaunch does not take it back.
    var isControlReleased: Bool { get }

    /// Stop bidding for the device; keep keys and pairing.
    func releaseControl()

    /// Connect, and keep reacquiring however the kit sees fit until ready or released. Readiness
    /// follows through `DeviceManagerDelegate.deviceManagerControlDidBecomeReady(_:)`.
    func takeControl()

    /// The link is up and the device has answered. Default: true.
    var isControlReady: Bool { get }

    /// Whether taking control with this export and local state means finding the device first
    /// (the host may need to keep its screen or radio awake). Default: false.
    static func takeControlNeedsSearch(adopting configuration: SharedDeviceConfiguration, localState: [String: Any]?) -> Bool
}

public extension ExclusiveDeviceControl {
    var isControlReady: Bool { true }
    static func takeControlNeedsSearch(adopting configuration: SharedDeviceConfiguration, localState: [String: Any]?) -> Bool { false }
}

public extension DeviceManagerDelegate {
    func deviceManagerControlDidBecomeReady(_ manager: DeviceManager) {}
}
