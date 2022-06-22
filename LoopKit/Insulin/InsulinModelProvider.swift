//
//  InsulinModelProvider.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

public protocol InsulinModelProvider {
    func model(for type: InsulinType?) -> InsulinModel
}

public struct PresetInsulinModelProvider: InsulinModelProvider {
    var defaultRapidActingModel: InsulinModel?
    
    public init(defaultRapidActingModel: InsulinModel?) {
        self.defaultRapidActingModel = defaultRapidActingModel
    }
    
    public func model(for type: InsulinType?) -> InsulinModel {
        switch type {
        case .fiasp:
            return ExponentialInsulinModelPreset.fiasp
        case .lyumjev:
            return ExponentialInsulinModelPreset.lyumjev
        case .afrezza:
            return ExponentialInsulinModelPreset.afrezza
        default:
            return defaultRapidActingModel ?? ExponentialInsulinModelPreset.rapidActingAdult
        }
    }
}

// Provides a fixed model, ignoring insulin type
public struct StaticInsulinModelProvider: InsulinModelProvider {
    var model: InsulinModel
    
    public init(_ model: InsulinModel) {
        self.model = model
    }
    
    public func model(for type: InsulinType?) -> InsulinModel {
        return model
    }
}


