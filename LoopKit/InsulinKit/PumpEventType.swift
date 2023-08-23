//
//  PumpEventType.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


/// A subset of pump event types
public enum PumpEventType: CaseIterable, Equatable {
   typealias RawValue = String
    
    case alarm
    case alarmClear
    case basal
    case bolus
    case prime
    case resume
    case rewind
    case suspend
    case tempBasal
    case replaceComponent(componentType: ReplaceableComponent)
    
    init?(rawValue: String) {
        switch rawValue {
        case "AlarmPump":
            self = .alarm
        case "ClearAlarm":
            self = .alarmClear
        case "BasalProfileStart":
            self = .basal
        case "Bolus":
            self = .bolus
        case "Prime":
            self = .prime
        case "PumpResume":
            self = .resume
        case "Rewind":
            self = .rewind
        case "PumpSuspend":
            self = .suspend
        case "TempBasal":
            self = .tempBasal
        default:
            if rawValue.starts(with: "Replace"), let value = ReplaceableComponent(rawValue: String(rawValue.dropFirst(7))) {
                self = .replaceComponent(componentType: value)
            } else {
                return nil
            }
        }
    }
    
    public var rawValue: String {
        switch self {
        case .alarm:
            return "AlarmPump"
        case .alarmClear:
            return "ClearAlarm"
        case .basal:
            return "BasalProfileStart"
        case .bolus:
            return "Bolus"
        case .prime:
            return "Prime"
        case .resume:
            return "PumpResume"
        case .rewind:
            return "Rewind"
        case .suspend:
            return "PumpSuspend"
        case .tempBasal:
            return "TempBasal"
        case let .replaceComponent(componentType):
            return "Replace\(componentType.rawValue)"
        }
    }
    
    public static var allCases: [PumpEventType] {
        return [.alarm, .alarmClear, .basal, .bolus, .prime, .resume, .rewind, .suspend, .tempBasal, .replaceComponent(componentType: .reservoir), .replaceComponent(componentType: .pump), .replaceComponent(componentType: .infusionSet)]
    }
}

/// A subset of replaceable component types
public enum ReplaceableComponent: String {
    case reservoir
    case pump // Base, pod or patch full replacement
    case infusionSet
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
        case .replaceComponent(componentType: .reservoir):
            return 10
        case .replaceComponent(componentType: .pump):
            return 11
        case .replaceComponent(componentType: .infusionSet):
            return 12
        }
    }
}
