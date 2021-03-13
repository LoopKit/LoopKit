//
//  DeviceManager.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import UserNotifications

public protocol DeviceManagerDelegate: AlertIssuer {
    // Begin obsolescent code
    // Note: once all plugins are updated to use the new alert system instead of Notifications, this can be removed.
    func scheduleNotification(for manager: DeviceManager,
                              identifier: String,
                              content: UNNotificationContent,
                              trigger: UNNotificationTrigger?)

    func clearNotification(for manager: DeviceManager, identifier: String)
    
    func removeNotificationRequests(for manager: DeviceManager, identifiers: [String])
    // End obsolescent code
    
    func deviceManager(_ manager: DeviceManager, logEventForDeviceIdentifier deviceIdentifier: String?, type: DeviceLogEntryType, message: String, completion: ((Error?) -> Void)?)
}

public protocol DeviceManager: CustomDebugStringConvertible, AlertResponder, AlertSoundVendor {
    typealias RawStateValue = [String: Any]

    /// A unique identifier for this manager
    var managerIdentifier: String { get }
    
    /// A title describing this manager
    var localizedTitle: String { get }

    /// The queue on which delegate methods are called
    /// Setting to nil resets to a default provided by the manager
    var delegateQueue: DispatchQueue! { get set }
    
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
}
