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

    /// True for a manager built by `init(adopting:localState:)`; the kit hides setup, pairing and deletion.
    var isConfiguredByAnotherController: Bool { get }

    /// What this controller learned about the device that is its own (for example its Bluetooth
    /// handle): never in the export, and it should outlive this manager. The host keeps the latest
    /// value per `pluginIdentifier` (an export's `managerIdentifier`) and passes it to the next
    /// `init(adopting:localState:)`. Default: nil.
    var localState: [String: Any]? { get }
}

public extension DeviceConfigurationSharing {
    var localState: [String: Any]? { nil }
}

/// A device whose hardware allows one controller at a time. Release, take and readiness say
/// nothing about who the controllers are; that is the host's business.
public protocol ExclusiveDeviceControl: DeviceConfigurationSharing, DeviceManager {
    /// True while control is released. Persisted by the kit, so a relaunch does not take it back.
    var isControlReleased: Bool { get }

    /// Stop bidding for the device; keep keys and pairing.
    func releaseControl()

    /// Connect, searching for the device if this controller has never met it. Readiness follows
    /// through `DeviceManagerDelegate.deviceManagerControlDidBecomeReady(_:)`.
    func takeControl()

    /// The link is up and the device has answered. Default: true.
    var isControlReady: Bool { get }

    /// Escalate a take whose link has not come up to the most aggressive reacquisition the kit
    /// has. Idempotent. Returns what it did, for the caller to log; nil means nothing to escalate.
    @discardableResult func escalateTakeControl() -> String?

    /// What the link has actually been doing, for the host's logs. Default: nil.
    func connectionDiagnostics() -> String?

    /// When the device last showed evidence that another controller used it. Default: nil.
    var lastForeignSessionAt: Date? { get }

    /// The next `takeControl()` has to find the device first, which may need the host awake.
    /// Default: false.
    var takeControlNeedsSearch: Bool { get }

    /// The same question asked of an export and this controller's `localState` before adopting
    /// them: would this controller have to find the device first? Default: false.
    static func takeControlNeedsSearch(adopting configuration: SharedDeviceConfiguration, localState: [String: Any]?) -> Bool

    /// The last take failed in a way only a reset of the host's radio clears. Default: false.
    var hostRadioNeedsReset: Bool { get }
}

public extension ExclusiveDeviceControl {
    var isControlReady: Bool { true }
    func escalateTakeControl() -> String? { nil }
    func connectionDiagnostics() -> String? { nil }
    var lastForeignSessionAt: Date? { nil }
    var takeControlNeedsSearch: Bool { false }
    static func takeControlNeedsSearch(adopting configuration: SharedDeviceConfiguration, localState: [String: Any]?) -> Bool { false }
    var hostRadioNeedsReset: Bool { false }
}

public extension DeviceManagerDelegate {
    func deviceManagerControlDidBecomeReady(_ manager: DeviceManager) {}
}
