//
//  DoseType.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public enum DoseType: String {
    case Bolus     = "Bolus"
    case Resume    = "PumpResume"
    case Suspend   = "PumpSuspend"
    case TempBasal = "TempBasal"
}
