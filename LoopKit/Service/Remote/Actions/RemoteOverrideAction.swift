//
//  RemoteOverrideAction.swift
//  LoopKit
//
//  Created by Bill Gestrich on 12/25/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import Foundation

public struct RemoteOverrideAction: Codable {
    
    public let name: String
    public let durationTime: TimeInterval?
    public let remoteAddress: String
    
    static let maxDurationTime = TimeInterval(hours: 24) //Also defined in AddEditOverrideTableViewController ,would like to move somewhere common
    
    public init(name: String, durationTime: TimeInterval? = nil, remoteAddress: String) {
        self.name = name
        self.durationTime = durationTime
        self.remoteAddress = remoteAddress
    }
    
}

extension RemoteOverrideAction {
    public func toValidOverride(allowedPresets: [TemporaryScheduleOverridePreset]) throws -> TemporaryScheduleOverride {
        guard let preset = allowedPresets.first(where: { $0.name == name }) else {
            throw RemoteOverrideActionError.unknownPreset(name)
        }
        
        var remoteOverride = preset.createOverride(enactTrigger: .remote(remoteAddress))
        
        if let durationTime = durationTime {
            
            guard durationTime <= RemoteOverrideAction.maxDurationTime else {
                throw RemoteOverrideActionError.durationExceedsMax(RemoteOverrideAction.maxDurationTime)
            }
            
            guard durationTime >= 0 else {
                throw RemoteOverrideActionError.negativeDuration
            }
            
            if durationTime == 0 {
                remoteOverride.duration = .indefinite
            } else {
                remoteOverride.duration = .finite(durationTime)
            }
        }
        
        return remoteOverride
    }
}

public enum RemoteOverrideActionError: LocalizedError {
    case unknownPreset(String)
    case durationExceedsMax(TimeInterval)
    case negativeDuration
    
    public var errorDescription: String? {
        switch self {
        case .unknownPreset(let presetName):
            return String(format: NSLocalizedString("Unknown preset: %1$@", comment: "Remote command error description: unknown preset (1: preset name)."), presetName)
        case .durationExceedsMax(let maxDurationTime):
            return String(format: NSLocalizedString("Duration exceeds: %1$.1f hours", comment: "Remote command error description: duration exceed max (1: max duration in hours)."), maxDurationTime.hours)
        case .negativeDuration:
            return String(format: NSLocalizedString("Negative duration not allowed", comment: "Remote command error description: negative duration error."))
        }
    }
}
