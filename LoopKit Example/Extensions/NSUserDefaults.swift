//
//  NSUserDefaults.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit


extension NSUserDefaults {
    private enum Key: String {
        case BasalRateSchedule = "com.LoopKitExample.BasalRateSchedule"
        case CarbRatioSchedule = "com.LoopKitExample.CarbRatioSchedule"
        case InsulinActionDuration = "com.LoopKitExample.InsulinActionDuration"
        case InsulinSensitivitySchedule = "com.LoopKitExample.InsulinSensitivitySchedule"
        case GlucoseTargetRangeSchedule = "com.LoopKitExample.GlucoseTargetRangeSchedule"
        case MaximumBasalRatePerHour = "com.LoopKitExample.MaximumBasalRatePerHour"
        case MaximumBolus = "com.LoopKitExample.MaximumBolus"
        case PumpID = "com.LoopKitExample.PumpID"
        case PumpTimeZone = "com.LoopKitExample.PumpTimeZone"
        case TransmitterID = "com.LoopKitExample.TransmitterID"
        case TransmitterStartTime = "com.LoopKitExample.TransmitterStartTime"
    }

    var basalRateSchedule: BasalRateSchedule? {
        get {
            if let rawValue = dictionaryForKey(Key.BasalRateSchedule.rawValue) {
                return BasalRateSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            setObject(newValue?.rawValue, forKey: Key.BasalRateSchedule.rawValue)
        }
    }

    var carbRatioSchedule: CarbRatioSchedule? {
        get {
            if let rawValue = dictionaryForKey(Key.CarbRatioSchedule.rawValue) {
                return CarbRatioSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            setObject(newValue?.rawValue, forKey: Key.CarbRatioSchedule.rawValue)
        }
    }

    var insulinActionDuration: NSTimeInterval? {
        get {
            let value = doubleForKey(Key.InsulinActionDuration.rawValue)

            return value > 0 ? value : NSTimeInterval(hours: 4)
        }
        set {
            if let insulinActionDuration = newValue {
                setDouble(insulinActionDuration, forKey: Key.InsulinActionDuration.rawValue)
            } else {
                removeObjectForKey(Key.InsulinActionDuration.rawValue)
            }
        }
    }

    var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        get {
            if let rawValue = dictionaryForKey(Key.InsulinSensitivitySchedule.rawValue) {
                return InsulinSensitivitySchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            setObject(newValue?.rawValue, forKey: Key.InsulinSensitivitySchedule.rawValue)
        }
    }

    var glucoseTargetRangeSchedule: GlucoseRangeSchedule? {
        get {
            if let rawValue = dictionaryForKey(Key.GlucoseTargetRangeSchedule.rawValue) {
                return GlucoseRangeSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            setObject(newValue?.rawValue, forKey: Key.GlucoseTargetRangeSchedule.rawValue)
        }
    }

    var maximumBasalRatePerHour: Double? {
        get {
            let value = doubleForKey(Key.MaximumBasalRatePerHour.rawValue)

            return value > 0 ? value : nil
        }
        set {
            if let maximumBasalRatePerHour = newValue {
                setDouble(maximumBasalRatePerHour, forKey: Key.MaximumBasalRatePerHour.rawValue)
            } else {
                removeObjectForKey(Key.MaximumBasalRatePerHour.rawValue)
            }
        }
    }

    var maximumBolus: Double? {
        get {
            let value = doubleForKey(Key.MaximumBolus.rawValue)

            return value > 0 ? value : nil
        }
        set {
            if let maximumBolus = newValue {
                setDouble(maximumBolus, forKey: Key.MaximumBolus.rawValue)
            } else {
                removeObjectForKey(Key.MaximumBolus.rawValue)
            }
        }
    }

    var pumpID: String? {
        get {
            return stringForKey(Key.PumpID.rawValue) ?? "123456"
        }
        set {
            setObject(newValue, forKey: Key.PumpID.rawValue)
        }
    }

    var pumpTimeZone: NSTimeZone? {
        get {
            if let offset = objectForKey(Key.PumpTimeZone.rawValue) as? NSNumber {
                return NSTimeZone(forSecondsFromGMT: offset.integerValue)
            } else {
                return nil
            }
        } set {
            if let value = newValue {
                setObject(NSNumber(integer: value.secondsFromGMT), forKey: Key.PumpTimeZone.rawValue)
            } else {
                removeObjectForKey(Key.PumpTimeZone.rawValue)
            }
        }
    }

    var transmitterStartTime: NSTimeInterval? {
        get {
            let value = doubleForKey(Key.TransmitterStartTime.rawValue)

            return value > 0 ? value : nil
        }
        set {
            if let value = newValue {
                setDouble(value, forKey: Key.TransmitterStartTime.rawValue)
            } else {
                removeObjectForKey(Key.TransmitterStartTime.rawValue)
            }
        }
    }

    var transmitterID: String? {
        get {
            return stringForKey(Key.TransmitterID.rawValue)
        }
        set {
            setObject(newValue, forKey: Key.TransmitterID.rawValue)
        }
    }

}
