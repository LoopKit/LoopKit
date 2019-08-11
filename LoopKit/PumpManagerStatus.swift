//
//  PumpManagerStatus.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct PumpManagerStatus: Equatable {
    
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
        case none
        case initiating
        case inProgress(_ dose: DoseEntry)
        case canceling
    }
    
    public let timeZone: TimeZone
    public let device: HKDevice
    public var pumpBatteryChargeRemaining: Double?
    public var basalDeliveryState: BasalDeliveryState
    public var bolusState: BolusState

    public init(
        timeZone: TimeZone,
        device: HKDevice,
        pumpBatteryChargeRemaining: Double?,
        basalDeliveryState: BasalDeliveryState,
        bolusState: BolusState
    ) {
        self.timeZone = timeZone
        self.device = device
        self.pumpBatteryChargeRemaining = pumpBatteryChargeRemaining
        self.basalDeliveryState = basalDeliveryState
        self.bolusState = bolusState
    }
}

extension PumpManagerStatus: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        ## PumpManagerStatus
        * timeZone: \(timeZone)
        * device: \(device)
        * pumpBatteryChargeRemaining: \(pumpBatteryChargeRemaining as Any)
        * basalDeliveryState: \(basalDeliveryState)
        * bolusState: \(bolusState)
        """
    }
}
