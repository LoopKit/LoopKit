//
//  PumpManagerStatus.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct PumpManagerStatus: Equatable {
    
    public struct PumpStatusHighlight: DeviceStatusHighlight, Equatable {
        public var localizedMessage: String
        
        public var imageName: String
        
        public var state: DeviceStatusHighlightState
        
        public init(localizedMessage: String, imageName: String, state: DeviceStatusHighlightState) {
            self.localizedMessage = localizedMessage
            self.imageName = imageName
            self.state = state
        }
    }
    
    public struct PumpLifecycleProgress: DeviceLifecycleProgress, Equatable {
        public var percentComplete: Double
        
        public var progressState: DeviceLifecycleProgressState
        
        public init(percentComplete: Double, progressState: DeviceLifecycleProgressState) {
            self.percentComplete = percentComplete
            self.progressState = progressState
        }
    }
    
    public enum BasalDeliveryState: Equatable {
        case active(_ at: Date)
        case initiatingTempBasal
        case tempBasal(_ dose: DoseEntry)
        case cancelingTempBasal
        case suspending
        case suspended(_ at: Date)
        case resuming

        public var isSuspended: Bool {
            if case .suspended = self {
                return true
            }
            return false
        }
    }

    public enum BolusState: Equatable {
        case noBolus
        case initiating
        case inProgress(_ dose: DoseEntry)
        case canceling
    }
    
    public let timeZone: TimeZone
    public let device: HKDevice
    public var pumpBatteryChargeRemaining: Double?
    public var basalDeliveryState: BasalDeliveryState?
    public var bolusState: BolusState
    
    /// The type of insulin this pump is delivering, nil if pump is in a state where insulin type is unknown; i.e. between reservoirs, or pod changes
    public var insulinType: InsulinType?

    public var deliveryIsUncertain: Bool


    public init(
        timeZone: TimeZone,
        device: HKDevice,
        pumpBatteryChargeRemaining: Double?,
        basalDeliveryState: BasalDeliveryState?,
        bolusState: BolusState,
        insulinType: InsulinType?,
        deliveryIsUncertain: Bool = false
    ) {
        self.timeZone = timeZone
        self.device = device
        self.pumpBatteryChargeRemaining = pumpBatteryChargeRemaining
        self.basalDeliveryState = basalDeliveryState
        self.bolusState = bolusState
        self.insulinType = insulinType
        self.deliveryIsUncertain = deliveryIsUncertain
    }
}

extension PumpManagerStatus: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.timeZone = try container.decode(TimeZone.self, forKey: .timeZone)
        self.device = (try container.decode(CodableDevice.self, forKey: .device)).device
        self.pumpBatteryChargeRemaining = try container.decodeIfPresent(Double.self, forKey: .pumpBatteryChargeRemaining)
        self.basalDeliveryState = try container.decodeIfPresent(BasalDeliveryState.self, forKey: .basalDeliveryState)
        self.bolusState = try container.decode(BolusState.self, forKey: .bolusState)
        self.insulinType = try container.decode(InsulinType.self, forKey: .insulinType)
        self.deliveryIsUncertain = try container.decode(Bool.self, forKey: .deliveryIsUncertain)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeZone, forKey: .timeZone)
        try container.encode(CodableDevice(device), forKey: .device)
        try container.encodeIfPresent(pumpBatteryChargeRemaining, forKey: .pumpBatteryChargeRemaining)
        try container.encodeIfPresent(basalDeliveryState, forKey: .basalDeliveryState)
        try container.encode(bolusState, forKey: .bolusState)
        try container.encode(insulinType, forKey: .insulinType)
        try container.encode(deliveryIsUncertain, forKey: .deliveryIsUncertain)
    }

    private struct CodableDevice: Codable {
        let name: String?
        let manufacturer: String?
        let model: String?
        let hardwareVersion: String?
        let firmwareVersion: String?
        let softwareVersion: String?
        let localIdentifier: String?
        let udiDeviceIdentifier: String?

        init(_ device: HKDevice) {
            self.name = device.name
            self.manufacturer = device.manufacturer
            self.model = device.model
            self.hardwareVersion = device.hardwareVersion
            self.firmwareVersion = device.firmwareVersion
            self.softwareVersion = device.softwareVersion
            self.localIdentifier = device.localIdentifier
            self.udiDeviceIdentifier = device.udiDeviceIdentifier
        }

        var device: HKDevice {
            return HKDevice(name: name,
                            manufacturer: manufacturer,
                            model: model,
                            hardwareVersion: hardwareVersion,
                            firmwareVersion: firmwareVersion,
                            softwareVersion: softwareVersion,
                            localIdentifier: localIdentifier,
                            udiDeviceIdentifier: udiDeviceIdentifier)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case timeZone
        case device
        case pumpBatteryChargeRemaining
        case basalDeliveryState
        case bolusState
        case insulinType
        case deliveryIsUncertain
    }
}

extension PumpManagerStatus.BasalDeliveryState: Codable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            switch string {
            case CodableKeys.initiatingTempBasal.rawValue:
                self = .initiatingTempBasal
            case CodableKeys.cancelingTempBasal.rawValue:
                self = .cancelingTempBasal
            case CodableKeys.suspending.rawValue:
                self = .suspending
            case CodableKeys.resuming.rawValue:
                self = .resuming
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodableKeys.self)
            if let active = try container.decodeIfPresent(Active.self, forKey: .active) {
                self = .active(active.at)
            } else if let tempBasal = try container.decodeIfPresent(TempBasal.self, forKey: .tempBasal) {
                self = .tempBasal(tempBasal.dose)
            } else if let suspended = try container.decodeIfPresent(Suspended.self, forKey: .suspended) {
                self = .suspended(suspended.at)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .active(let at):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(Active(at: at), forKey: .active)
        case .initiatingTempBasal:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.initiatingTempBasal.rawValue)
        case .tempBasal(let dose):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(TempBasal(dose: dose), forKey: .tempBasal)
        case .cancelingTempBasal:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.cancelingTempBasal.rawValue)
        case .suspending:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.suspending.rawValue)
        case .suspended(let at):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(Suspended(at: at), forKey: .suspended)
        case .resuming:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.resuming.rawValue)
        }
    }

    private struct Active: Codable {
        let at: Date
    }

    private struct TempBasal: Codable {
        let dose: DoseEntry
    }

    private struct Suspended: Codable {
        let at: Date
    }

    private enum CodableKeys: String, CodingKey {
        case active
        case initiatingTempBasal
        case tempBasal
        case cancelingTempBasal
        case suspending
        case suspended
        case resuming
    }
}

extension PumpManagerStatus.BolusState: Codable {
    public init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            switch string {
            case CodableKeys.noBolus.rawValue, "none": // included for backward compatibility. BolusState.none -> BolusState.noBolus
                self = .noBolus
            case CodableKeys.initiating.rawValue:
                self = .initiating
            case CodableKeys.canceling.rawValue:
                self = .canceling
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        } else {
            let container = try decoder.container(keyedBy: CodableKeys.self)
            if let inProgress = try container.decodeIfPresent(InProgress.self, forKey: .inProgress) {
                self = .inProgress(inProgress.dose)
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "invalid enumeration"))
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .noBolus:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.noBolus.rawValue)
        case .initiating:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.initiating.rawValue)
        case .inProgress(let dose):
            var container = encoder.container(keyedBy: CodableKeys.self)
            try container.encode(InProgress(dose: dose), forKey: .inProgress)
        case .canceling:
            var container = encoder.singleValueContainer()
            try container.encode(CodableKeys.canceling.rawValue)
        }
    }

    private struct InProgress: Codable {
        let dose: DoseEntry
    }

    private enum CodableKeys: String, CodingKey {
        case noBolus
        case initiating
        case inProgress
        case canceling
    }
}

extension PumpManagerStatus.PumpStatusHighlight: Codable { }

extension PumpManagerStatus.PumpLifecycleProgress: Codable { }

extension PumpManagerStatus: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        ## PumpManagerStatus
        * timeZone: \(timeZone)
        * device: \(device)
        * pumpBatteryChargeRemaining: \(pumpBatteryChargeRemaining as Any)
        * basalDeliveryState: \(basalDeliveryState as Any)
        * bolusState: \(bolusState)
        * insulinType: \(insulinType as Any)
        * deliveryIsUncertain: \(deliveryIsUncertain)
        """
    }
}
