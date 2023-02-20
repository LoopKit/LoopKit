//
//  LoopNotificationCategory.swift
//  LoopKit
//
//  Created by Pete Schwamb on 4/8/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public enum LoopNotificationCategory: String {
    case bolusFailure
    case loopNotRunning
    case pumpBatteryLow
    case pumpReservoirEmpty
    case pumpReservoirLow
    case pumpExpirationWarning
    case pumpExpired
    case pumpFault
    case alert
    case remoteBolus
    case remoteBolusFailure
    case remoteCommandExpired
    case remoteCarbs
    case remoteCarbsFailure
    case missedMeal
}
