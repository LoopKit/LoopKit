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
        case afrezza
        case fiasp
        case lyumjev
        case rapidAdult
        case rapidChild
    }

    public let modelType: ModelType
    public let delay: TimeInterval
    public let actionDuration: TimeInterval
    public let peakActivity: TimeInterval

    public init(modelType: ModelType, delay: TimeInterval, actionDuration: TimeInterval, peakActivity: TimeInterval) {
        self.modelType = modelType
        self.delay = delay
        self.actionDuration = actionDuration
        self.peakActivity = peakActivity
    }
}

public extension StoredInsulinModel {
    init(_ preset: ExponentialInsulinModelPreset) {
        var modelType: StoredInsulinModel.ModelType

        switch preset {
        case .afrezza:
            modelType = .afrezza
        case .fiasp:
            modelType = .fiasp
        case .lyumjev:
            modelType = .lyumjev
        case .rapidActingAdult:
            modelType = .rapidAdult
        case .rapidActingChild:
            modelType = .rapidChild
        }

        self.init(modelType: modelType, delay: preset.delay, actionDuration: preset.actionDuration, peakActivity: preset.peakActivity)
    }

    var presetForRapidActingInsulin: ExponentialInsulinModelPreset? {
        switch modelType {
        case .rapidAdult:
            return .rapidActingAdult
        case .rapidChild:
            return .rapidActingChild
        default:
            return nil
        }
    }
}
