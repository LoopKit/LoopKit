//
//  NSUserDefaults.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit


extension UserDefaults {
    private enum Key: String {
        case BasalRateSchedule = "com.LoopKitExample.BasalRateSchedule"
        case CarbRatioSchedule = "com.LoopKitExample.CarbRatioSchedule"
        case InsulinActionDuration = "com.LoopKitExample.InsulinActionDuration"
        case InsulinSensitivitySchedule = "com.LoopKitExample.InsulinSensitivitySchedule"
        case GlucoseTargetRangeSchedule = "com.LoopKitExample.GlucoseTargetRangeSchedule"
        case PreMealTargetRange = "com.LoopKitExample.PreMealTargetRange"
        case LegacyWorkoutTargetRange = "com.LoopKitExample.LegacyWorkoutTargetRange"
        case MaximumBasalRatePerHour = "com.LoopKitExample.MaximumBasalRatePerHour"
        case MaximumBolus = "com.LoopKitExample.MaximumBolus"
        case PumpID = "com.LoopKitExample.PumpID"
        case PumpTimeZone = "com.LoopKitExample.PumpTimeZone"
        case TransmitterID = "com.LoopKitExample.TransmitterID"
        case TransmitterStartTime = "com.LoopKitExample.TransmitterStartTime"
    }

    var basalRateSchedule: BasalRateSchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.BasalRateSchedule.rawValue) {
                return BasalRateSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.BasalRateSchedule.rawValue)
        }
    }

    var carbRatioSchedule: CarbRatioSchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.CarbRatioSchedule.rawValue) {
                return CarbRatioSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.CarbRatioSchedule.rawValue)
        }
    }

    var insulinActionDuration: TimeInterval? {
        get {
            let value = double(forKey: Key.InsulinActionDuration.rawValue)

            return value > 0 ? value : TimeInterval(hours: 4)
        }
        set {
            if let insulinActionDuration = newValue {
                set(insulinActionDuration, forKey: Key.InsulinActionDuration.rawValue)
            } else {
                removeObject(forKey: Key.InsulinActionDuration.rawValue)
            }
        }
    }

    var insulinSensitivitySchedule: InsulinSensitivitySchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.InsulinSensitivitySchedule.rawValue) {
                return InsulinSensitivitySchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.InsulinSensitivitySchedule.rawValue)
        }
    }

    var glucoseTargetRangeSchedule: GlucoseRangeSchedule? {
        get {
            if let rawValue = dictionary(forKey: Key.GlucoseTargetRangeSchedule.rawValue) {
                return GlucoseRangeSchedule(rawValue: rawValue)
            } else {
                return nil
            }
        }
        set {
            set(newValue?.rawValue, forKey: Key.GlucoseTargetRangeSchedule.rawValue)
        }
    }

    var preMealTargetRange: DoubleRange? {
        get {
            if let rawValue = array(forKey: Key.PreMealTargetRange.rawValue) as? DoubleRange.RawValue {
                return DoubleRange(rawValue: rawValue)
            } else {
                return nil
            }
        }

        set {
            set(newValue?.rawValue, forKey: Key.PreMealTargetRange.rawValue)
        }
    }


    var legacyWorkoutTargetRange: DoubleRange? {
        get {
            if let rawValue = array(forKey: Key.LegacyWorkoutTargetRange.rawValue) as? DoubleRange.RawValue {
                return DoubleRange(rawValue: rawValue)
            } else {
                return nil
            }
        }

        set {
            set(newValue?.rawValue, forKey: Key.LegacyWorkoutTargetRange.rawValue)
        }
    }

    var maximumBasalRatePerHour: Double? {
        get {
            let value = double(forKey: Key.MaximumBasalRatePerHour.rawValue)

            return value > 0 ? value : nil
        }
        set {
            if let maximumBasalRatePerHour = newValue {
                set(maximumBasalRatePerHour, forKey: Key.MaximumBasalRatePerHour.rawValue)
            } else {
                removeObject(forKey: Key.MaximumBasalRatePerHour.rawValue)
            }
        }
    }

    var maximumBolus: Double? {
        get {
            let value = double(forKey: Key.MaximumBolus.rawValue)

            return value > 0 ? value : nil
        }
        set {
            if let maximumBolus = newValue {
                set(maximumBolus, forKey: Key.MaximumBolus.rawValue)
            } else {
                removeObject(forKey: Key.MaximumBolus.rawValue)
            }
        }
    }

    var pumpID: String? {
        get {
            return string(forKey: Key.PumpID.rawValue) ?? "123456"
        }
        set {
            set(newValue, forKey: Key.PumpID.rawValue)
        }
    }

    var pumpTimeZone: TimeZone? {
        get {
            if let offset = object(forKey: Key.PumpTimeZone.rawValue) as? NSNumber {
                return TimeZone(secondsFromGMT: offset.intValue)
            } else {
                return nil
            }
        } set {
            if let value = newValue {
                set(NSNumber(value: value.secondsFromGMT()), forKey: Key.PumpTimeZone.rawValue)
            } else {
                removeObject(forKey: Key.PumpTimeZone.rawValue)
            }
        }
    }

    var transmitterStartTime: TimeInterval? {
        get {
            let value = double(forKey: Key.TransmitterStartTime.rawValue)

            return value > 0 ? value : nil
        }
        set {
            if let value = newValue {
                set(value, forKey: Key.TransmitterStartTime.rawValue)
            } else {
                removeObject(forKey: Key.TransmitterStartTime.rawValue)
            }
        }
    }

    var transmitterID: String? {
        get {
            return string(forKey: Key.TransmitterID.rawValue)
        }
        set {
            set(newValue, forKey: Key.TransmitterID.rawValue)
        }
    }

}
