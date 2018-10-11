//
//  PumpManagerStatus.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct PumpManagerStatus: Equatable {
    
    typealias RawValue = [String: Any]

    public let timeZone: TimeZone
    public let device: HKDevice
    public var pumpBatteryChargeRemaining: Double?
    public var isSuspended: Bool
    public var isBolusing: Bool

    public init(
        timeZone: TimeZone,
        device: HKDevice,
        pumpBatteryChargeRemaining: Double?,
        isSuspended: Bool,
        isBolusing: Bool
    ) {
        self.timeZone = timeZone
        self.device = device
        self.pumpBatteryChargeRemaining = pumpBatteryChargeRemaining
        self.isSuspended = isSuspended
        self.isBolusing = isBolusing
    }
}
