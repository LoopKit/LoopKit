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
    case bolus     = "Bolus"
    case resume    = "PumpResume"
    case suspend   = "PumpSuspend"
    case tempBasal = "TempBasal"
}
