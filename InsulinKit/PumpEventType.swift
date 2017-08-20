//
//  PumpEventType.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


/// A subset of pump event types, with raw values matching decocare's strings
public enum PumpEventType: String {
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
