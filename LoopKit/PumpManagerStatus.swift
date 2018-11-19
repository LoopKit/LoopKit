//
//  PumpManagerStatus.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct PumpManagerStatus: Equatable {
    
    public enum SuspendState: Equatable {
        case none
        case suspending
        case suspended
        case resuming
    }
    
    public enum BolusState: Equatable {
        case none
        case initiatingBolus
        case bolusing(progress: Float?)
        case cancelingBolus
    }
    
    public let timeZone: TimeZone
    public let device: HKDevice
    public var pumpBatteryChargeRemaining: Double?
    public var suspendState: SuspendState
    public var bolusState: BolusState

    public init(
        timeZone: TimeZone,
        device: HKDevice,
        pumpBatteryChargeRemaining: Double?,
        suspendState: SuspendState,
        bolusState: BolusState
    ) {
        self.timeZone = timeZone
        self.device = device
        self.pumpBatteryChargeRemaining = pumpBatteryChargeRemaining
        self.suspendState = suspendState
        self.bolusState = bolusState
    }
}
