//
//  NSUserDefaults.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 4/3/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


extension NSUserDefaults {
    private enum Key: String {
        case PumpEventQueryAfterDate = "com.loudnate.InsulinKit.PumpEventQueryAfterDate"
    }

    var pumpEventQueryAfterDate: NSDate? {
        get {
            return objectForKey(Key.PumpEventQueryAfterDate.rawValue) as? NSDate
        }
        set {
            setObject(newValue, forKey: Key.PumpEventQueryAfterDate.rawValue)
        }
    }
}