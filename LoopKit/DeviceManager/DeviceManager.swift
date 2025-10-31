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
}
