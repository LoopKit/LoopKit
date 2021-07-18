//
//  StoredInsulinModel.swift
//  LoopKit
//
//  Created by Darin Krauss on 7/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public struct StoredInsulinModel: Codable, Equatable {
    public enum ModelType: String, Codable {
        case fiasp
        case rapidAdult
        case rapidChild
    }

    public let modelType: ModelType
    public let actionDuration: TimeInterval
    public let peakActivity: TimeInterval?

    public init(modelType: ModelType, actionDuration: TimeInterval, peakActivity: TimeInterval? = nil) {
        self.modelType = modelType
        self.actionDuration = actionDuration
        self.peakActivity = peakActivity
    }
}

public extension StoredInsulinModel {
    init(_ preset: ExponentialInsulinModelPreset) {
        var modelType: StoredInsulinModel.ModelType
        var actionDuration: TimeInterval
        var peakActivity: TimeInterval?
        
        switch preset {
        case .rapidActingAdult:
            modelType = .rapidAdult
        case .rapidActingChild:
            modelType = .rapidChild
        case .fiasp:
            modelType = .fiasp
        }
        actionDuration = preset.actionDuration
        peakActivity = preset.peakActivity
        
        self.init(modelType: modelType, actionDuration: actionDuration, peakActivity: peakActivity)
    }
}

