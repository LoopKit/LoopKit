//
//  RemoteAction.swift
//  LoopKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public enum RemoteAction: CustomStringConvertible, Codable {
    case temporaryScheduleOverride(RemoteOverrideAction)
    case cancelTemporaryOverride(RemoteOverrideCancelAction)
    case bolusEntry(RemoteBolusAction)
    case carbsEntry(RemoteCarbAction)
    case closedLoop(RemoteClosedLoopAction)
    case autobolus(RemoteAutobolusAction)
    
    public var description: String {
        return "\(actionName) \(actionDetails)"
    }
    
    var actionName: String {
        switch self {
        case .carbsEntry:
            return "Carb Entry"
        case .bolusEntry:
            return "Bolus Entry"
        case .cancelTemporaryOverride:
            return "Cancel Override"
        case .temporaryScheduleOverride:
            return "Override"
        case .closedLoop:
            return "Closed Loop Update"
        case .autobolus:
            return "Autobolus Update"
        }
    }
    
    var actionDetails: String {
        switch self {
        case .carbsEntry(let carbAction):
            return "\(carbAction.amountInGrams)g"
        case .bolusEntry(let bolusAction):
            return "\(bolusAction.amountInUnits)u"
        case .cancelTemporaryOverride:
            return ""
        case .temporaryScheduleOverride(let overrideAction):
            return "\(overrideAction.name)"
        case .autobolus(let autobolusAction):
            return autobolusAction.active ? "Activate" : "Deactivate"
        case .closedLoop(let closedLoopAction):
            return closedLoopAction.active ? "Activate" : "Deactivate"
        }
    }
}
