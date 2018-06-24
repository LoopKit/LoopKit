//
//  PumpManagerStatus.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public struct PumpManagerStatus: Equatable {
    public let date: Date
    public let timeZone: TimeZone
    public let device: HKDevice?
    public var lastValidFrequency: Measurement<UnitFrequency>?
    public var lastTuned: Date?
    public var battery: BatteryStatus?
    public var isSuspended: Bool?
    public var isBolusing: Bool?
    public var remainingReservoir: HKQuantity?

    public struct BatteryStatus: Equatable {
        public let percent: Double?
        public let voltage: Measurement<UnitElectricPotentialDifference>?
        public let state: State?

        public enum State {
            case normal
            case low
        }

        public init?(
            percent: Double? = nil,
            voltage: Measurement<UnitElectricPotentialDifference>? = nil,
            state: State? = nil
        ) {
            guard percent != nil || voltage != nil || state != nil else {
                return nil
            }

            self.percent = percent
            self.voltage = voltage
            self.state = state
        }
    }

    public init(
        date: Date,
        timeZone: TimeZone,
        device: HKDevice?,
        lastValidFrequency: Measurement<UnitFrequency>?,
        lastTuned: Date?,
        battery: BatteryStatus?,
        isSuspended: Bool?,
        isBolusing: Bool?,
        remainingReservoir: HKQuantity?
    ) {
        self.date = date
        self.timeZone = timeZone
        self.device = device
        self.lastValidFrequency = lastValidFrequency
        self.lastTuned = lastTuned
        self.battery = battery
        self.isSuspended = isSuspended
        self.isBolusing = isBolusing
        self.remainingReservoir = remainingReservoir
    }
}
