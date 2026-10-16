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
    var defaultRapidActingModel: ExponentialInsulinModelPreset?
    
    public init(defaultRapidActingModel: ExponentialInsulinModelPreset?) {
        self.defaultRapidActingModel = defaultRapidActingModel
    }
    
    public func model(for type: InsulinType?) -> InsulinModel {
        switch type {
        case .fiasp:
            return ExponentialInsulinModelPreset.fiasp.model
        case .lyumjev:
            return ExponentialInsulinModelPreset.lyumjev.model
        case .afrezza:
            return ExponentialInsulinModelPreset.afrezza.model
        default:
            return (defaultRapidActingModel ?? ExponentialInsulinModelPreset.rapidActingAdult).model
        }
    }
}

// Provides a fixed model, ignoring insulin type
public struct StaticInsulinModelProvider: InsulinModelProvider {
    var model: InsulinModel
    
    public init(_ model: InsulinModel) {
        self.model = model
    }
    
    public init(_ preset: ExponentialInsulinModelPreset) {
        self.model = preset.model
    }
    
    public func model(for type: InsulinType?) -> InsulinModel {
        return model
    }
}


