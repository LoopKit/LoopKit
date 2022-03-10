//
//  PumpAlarmType.swift
//  LoopKit
//
//  Created by Darin Krauss on 1/10/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public enum PumpAlarmType: Equatable, Codable {
    case autoOff
    case lowInsulin
    case lowPower
    case noDelivery
    case noInsulin
    case noPower
    case occlusion
    case other(_ details: String)
}

extension PumpAlarmType: RawRepresentable {
    public typealias RawValue = String

    public init(rawValue: String) {
        switch rawValue {
        case "autoOff":
            self = .autoOff
        case "lowInsulin":
            self = .lowInsulin
        case "lowPower":
            self = .lowPower
        case "noDelivery":
            self = .noDelivery
        case "noInsulin":
            self = .noInsulin
        case "noPower":
            self = .noPower
        case "occlusion":
            self = .occlusion
        default:
            self = .other(rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .autoOff:
            return "autoOff"
        case .lowInsulin:
            return "lowInsulin"
        case .lowPower:
            return "lowPower"
        case .noDelivery:
            return "noDelivery"
        case .noInsulin:
            return "noInsulin"
        case .noPower:
            return "noPower"
        case .occlusion:
            return "occlusion"
        case .other(let details):
            return details
        }
    }
}
