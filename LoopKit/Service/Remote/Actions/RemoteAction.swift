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
    
    public var description: String {
        return "\(actionName) \(actionDetails)"
    }
    
    var actionName: String {
        switch self {
        case .carbsEntry:
            return NSLocalizedString("Carb Entry", comment: "Carb entry action name")
        case .bolusEntry:
            return NSLocalizedString("Bolus Entry", comment: "Bolus entry action name")
        case .cancelTemporaryOverride:
            return NSLocalizedString("Cancel Override", comment: "Cancel override action name")
        case .temporaryScheduleOverride:
            return NSLocalizedString("Override", comment: "Override action name")
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
        }
    }
}
