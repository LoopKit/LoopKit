//
//  PumpEventType.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


/// A subset of pump event types, with raw values matching decocare's strings
public enum PumpEventType: String, CaseIterable {
    case alarm      = "AlarmPump"
    case alarmClear = "ClearAlarm"
    case basal      = "BasalProfileStart"
    case bolus      = "Bolus"
    case prime      = "Prime"
    case resume     = "PumpResume"
    case rewind     = "Rewind"
    case suspend    = "PumpSuspend"
    case tempBasal  = "TempBasal"
}


extension PumpEventType {
    /// Provides an ordering between types used for stable, chronological sorting for doses that share the same date.
    var sortOrder: Int {
        switch self {
        case .bolus:
            return 1
        // An alarm should happen before a clear
        case .alarm:
            return 2
        case .alarmClear:
            return 3
        // A rewind should happen before a prime
        case .rewind:
            return 4
        case .prime:
            return 5
        // A suspend should always happen before a resume
        case .suspend:
            return 6
        // A resume should happen before basal delivery begins
        case .resume:
            return 7
        // A 0-second temporary basal cancelation should happen before schedule basal delivery
        case .tempBasal:
            return 8
        case .basal:
            return 9
        }
    }
}
