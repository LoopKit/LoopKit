//
//  Alert.swift
//  LoopKit
//
//  Created by Rick Pasetto on 4/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

/// Protocol that describes any class that issues and retract Alerts.
public protocol AlertIssuer: AnyObject {
    /// Issue (post) the given alert, according to its trigger schedule.
    func issueAlert(_ alert: Alert)
    /// Retract any alerts with the given identifier.  This includes both pending and delivered alerts.
    func retractAlert(identifier: Alert.Identifier)
}

/// Protocol that describes something that can deal with a user's response to an alert.
public protocol AlertResponder: AnyObject {
    /// Acknowledge alerts with a given type identifier
    func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier) -> Void
}

/// Structure that represents an Alert that is issued from a Device.
public struct Alert: Equatable {
    /// Representation of an alert Trigger
    public enum Trigger: Equatable {
        /// Trigger the alert immediately
        case immediate
        /// Delay triggering the alert by `interval`, but issue it only once.
        case delayed(interval: TimeInterval)
        /// Delay triggering the alert by `repeatInterval`, and repeat at that interval until cancelled or unscheduled.
        case repeating(repeatInterval: TimeInterval)
    }
    /// Content of the alert, either for foreground or background alerts
    public struct Content: Equatable  {
        public let title: String
        public let body: String
        /// Should this alert be deemed "critical" for the User?  Handlers will determine how that is manifested.
        public let isCritical: Bool
        // TODO: when we have more complicated actions.  For now, all we have is "acknowledge".
//        let actions: [UserAlertAction]
        public let acknowledgeActionButtonLabel: String
        public init(title: String, body: String, acknowledgeActionButtonLabel: String, isCritical: Bool = false) {
            self.title = title
            self.body = body
            self.acknowledgeActionButtonLabel = acknowledgeActionButtonLabel
            self.isCritical = isCritical
        }
    }
    public struct Identifier: Equatable, Hashable {
        /// Unique device manager identifier from whence the alert came, and to which alert acknowledgements should be directed.
        public let managerIdentifier: String
        /// Per-alert-type identifier, for instance to group alert types.  This is the identifier that will be used to acknowledge the alert.
        public let alertIdentifier: AlertIdentifier
        public init(managerIdentifier: String, alertIdentifier: AlertIdentifier) {
            self.managerIdentifier = managerIdentifier
            self.alertIdentifier = alertIdentifier
        }
        /// An opaque value for this tuple for unique identification of the alert across devices.
        public var value: String {
            return "\(managerIdentifier).\(alertIdentifier)"
        }
    }
    /// This type represents a per-alert-type identifier, but not necessarily unique across devices.  Each device may have its own Swift type for this,
    /// so conversion to String is the most convenient, but aliasing the type is helpful because it is not just "any String".
    public typealias AlertIdentifier = String

    /// Alert content to show while app is in the foreground.  If nil, there shall be no alert while app is in the foreground.
    public let foregroundContent: Content?
    /// Alert content to show while app is in the background.  If nil, there shall be no alert while app is in the background.
    public let backgroundContent: Content?
    /// Trigger for the alert.
    public let trigger: Trigger

    /// An alert's "identifier" is a tuple of `managerIdentifier` and `alertIdentifier`.  It's purpose is to uniquely identify an alert so we can
    /// find which device issued it, and send acknowledgment of that alert to the proper device manager.
    public let identifier: Identifier

    /// Representation of a "sound" (or other sound-like action, like vibrate) to perform when the alert is issued.
    public enum Sound: Equatable {
        case vibrate
        case silence
        case sound(name: String)
    }
    public let sound: Sound?
    
    public init(identifier: Identifier, foregroundContent: Content?, backgroundContent: Content?, trigger: Trigger, sound: Sound? = nil) {
        self.identifier = identifier
        self.foregroundContent = foregroundContent
        self.backgroundContent = backgroundContent
        self.trigger = trigger
        self.sound = sound
    }
}

public extension Alert.Sound {
    var filename: String? {
        switch self {
        case .sound(let name): return name
        case .silence, .vibrate: return nil
        }
    }
}

public protocol AlertSoundVendor {
    // Get the base URL for where to find all the vendor's sounds.  It is under here that all of the sound files should be.
    // Returns nil if the vendor has no sounds.
    func getSoundBaseURL() -> URL?
    // Get all the sounds for this vendor.  Returns an empty array if the vendor has no sounds.
    func getSounds() -> [Alert.Sound]
}

// MARK: Codable implementations

extension Alert: Codable { }
extension Alert.Content: Codable { }
extension Alert.Identifier: Codable { }
// These Codable implementations of enums with associated values cannot be synthesized (yet) in Swift.
// The code below follows a pattern described by https://medium.com/@hllmandel/codable-enum-with-associated-values-swift-4-e7d75d6f4370
extension Alert.Trigger: Codable {
    private enum CodingKeys: String, CodingKey {
      case immediate, delayed, repeating
    }
    private struct Delayed: Codable {
        let delayInterval: TimeInterval
    }
    private struct Repeating: Codable {
        let repeatInterval: TimeInterval
    }
    public init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer().decode(CodingKeys.RawValue.self) {
            switch singleValue {
            case CodingKeys.immediate.rawValue:
                self = .immediate
            default:
                throw decoder.enumDecodingError
            }
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let delayInterval = try? container.decode(Delayed.self, forKey: .delayed) {
                self = .delayed(interval: delayInterval.delayInterval)
            } else if let repeatInterval = try? container.decode(Repeating.self, forKey: .repeating) {
                self = .repeating(repeatInterval: repeatInterval.repeatInterval)
            } else {
                throw decoder.enumDecodingError
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .immediate:
            var container = encoder.singleValueContainer()
            try container.encode(CodingKeys.immediate.rawValue)
        case .delayed(let interval):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Delayed(delayInterval: interval), forKey: .delayed)
        case .repeating(let repeatInterval):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(Repeating(repeatInterval: repeatInterval), forKey: .repeating)
        }
    }
}

extension Alert.Sound: Codable {
    private enum CodingKeys: String, CodingKey {
      case silence, vibrate, sound
    }
    private struct SoundName: Codable {
        let name: String
    }
    public init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer().decode(CodingKeys.RawValue.self) {
            switch singleValue {
            case CodingKeys.silence.rawValue:
                self = .silence
            case CodingKeys.vibrate.rawValue:
                self = .vibrate
            default:
                throw decoder.enumDecodingError
            }
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let name = try? container.decode(SoundName.self, forKey: .sound) {
                self = .sound(name: name.name); return
            } else {
                throw decoder.enumDecodingError
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .silence:
            var container = encoder.singleValueContainer()
            try container.encode(CodingKeys.silence.rawValue)
        case .vibrate:
            var container = encoder.singleValueContainer()
            try container.encode(CodingKeys.vibrate.rawValue)
        case .sound(let name):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(SoundName(name: name), forKey: .sound)
        }
    }
}

extension Decoder {
    var enumDecodingError: DecodingError {
        return DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "invalid enumeration"))
    }
}

