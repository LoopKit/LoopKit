//
//  SmartwatchManager+Host.swift
//  LoopKit
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

// What a host does with a watch plugin's log lines and device alerts, in LoopKit's
// own types, so every host maps them the same way. `SmartwatchManager.swift`
// itself uses no other LoopKit type.

public extension DeviceLogEntryType {
    /// The device log type for a watch plugin's log line.
    init(_ type: SmartwatchDeviceLogEntry.EntryType) {
        switch type {
        case .send: self = .send
        case .receive: self = .receive
        case .error: self = .error
        case .delegate: self = .delegate
        case .delegateResponse: self = .delegateResponse
        case .connection: self = .connection
        }
    }
}

public extension Alert.Identifier {
    /// The host's identifier for a watch plugin's device alert: the plugin is the
    /// alert's manager, so the same identifier retracts it.
    init(_ identifier: SmartwatchAlertIdentifier, from manager: SmartwatchManager) {
        self.init(managerIdentifier: manager.pluginIdentifier, alertIdentifier: identifier.value)
    }
}

public extension Alert {
    /// A watch plugin's device alert as the host's own alert from that plugin,
    /// shown at once. A plugin can't raise a critical alert: informational alerts
    /// are active, the others time-sensitive.
    init(_ alert: SmartwatchDeviceAlert, from manager: SmartwatchManager, acknowledgeActionButtonLabel: String) {
        let content = Alert.Content(title: alert.title, body: alert.body, acknowledgeActionButtonLabel: acknowledgeActionButtonLabel)
        self.init(
            identifier: Alert.Identifier(alert.identifier, from: manager),
            foregroundContent: content,
            backgroundContent: content,
            trigger: .immediate,
            interruptionLevel: alert.level == .informational ? .active : .timeSensitive
        )
    }
}
