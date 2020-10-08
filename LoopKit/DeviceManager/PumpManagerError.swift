//
//  PumpManagerError.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//


public enum PumpManagerError: Error {
    /// The manager isn't configured correctly
    case configuration(LocalizedError?)

    /// The device connection failed
    case connection(LocalizedError?)

    /// The device is connected, but communication failed
    case communication(LocalizedError?)

    /// The device is in an error state
    case deviceState(LocalizedError?)
    
    /// A command issued to the pump was sent, but we do not know if the pump received it
    case uncertainDelivery
}


extension PumpManagerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .communication(let error):
            return error?.errorDescription ?? LocalizedString("Communication Failure", comment: "Generic pump error description")
        case .configuration(let error):
            return error?.errorDescription ?? LocalizedString("Invalid Configuration", comment: "Generic pump error description")
        case .connection(let error):
            return error?.errorDescription ?? LocalizedString("Connection Failure", comment: "Generic pump error description")
        case .deviceState(let error):
            return error?.errorDescription ?? LocalizedString("Device Refused", comment: "Generic pump error description")
        case .uncertainDelivery:
            return LocalizedString("Uncertain Delivery", comment: "Error description for uncertain delivery")
        }
    }

    public var failureReason: String? {
        switch self {
        case .communication(let error):
            return error?.failureReason
        case .configuration(let error):
            return error?.failureReason
        case .connection(let error):
            return error?.failureReason
        case .deviceState(let error):
            return error?.failureReason
        case .uncertainDelivery:
            return LocalizedString("Communications interrupted during insulin delivery command.", comment: "Failure reason for uncertain delivery")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .communication(let error):
            return error?.recoverySuggestion
        case .configuration(let error):
            return error?.recoverySuggestion
        case .connection(let error):
            return error?.recoverySuggestion
        case .deviceState(let error):
            return error?.recoverySuggestion
        case .uncertainDelivery:
            return LocalizedString("Make sure your pump is within communication range of your phone.", comment: "Recovery suggestion for uncertain delivery")
        }
    }

    public var helpAnchor: String? {
        switch self {
        case .communication(let error):
            return error?.helpAnchor
        case .configuration(let error):
            return error?.helpAnchor
        case .connection(let error):
            return error?.helpAnchor
        case .deviceState(let error):
            return error?.helpAnchor
        case .uncertainDelivery:
            return nil
        }
    }
}
