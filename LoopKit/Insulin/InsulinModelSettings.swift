//
//  InsulinModelSettings.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

public enum InsulinModelSettings: Equatable {
    case exponentialPreset(ExponentialInsulinModelPreset)

    public var longestEffectDuration: TimeInterval {
        switch self {
        case .exponentialPreset(let model):
            return model.effectDuration
        }
    }

    public func model(for type: InsulinType?) -> InsulinModel {
        guard let type = type else {
            switch self {
            case .exponentialPreset(let model):
                return model
            }
        }
        
        switch type {
        case .fiasp:
            return ExponentialInsulinModelPreset.fiasp
        default:
            switch self {
            case .exponentialPreset(let model):
                return model
            }
        }
    }

    public init?(model: InsulinModel) {
        switch model {
        case let model as ExponentialInsulinModelPreset:
            self = .exponentialPreset(model)
        default:
            return nil
        }
    }
}

extension InsulinModelSettings: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            let exponential =  try container.decode(ExponentialInsulinModelPreset.self, forKey: .exponential)
            self = .exponentialPreset(exponential)
        } catch {
            self = .exponentialPreset(ExponentialInsulinModelPreset.rapidActingAdult)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .exponentialPreset(let model):
            try container.encode(model, forKey: .exponential)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case exponential
    }
}

extension InsulinModelSettings: CustomDebugStringConvertible {
    public var debugDescription: String {
        return String(reflecting: model)
    }
}

extension InsulinModelSettings: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let typeName = rawValue["type"] as? InsulinModelType.RawValue,
            let type = InsulinModelType(rawValue: typeName)
        else {
            return nil
        }

        switch type {
        case .exponentialPreset:
            guard let modelRaw = rawValue["model"] as? ExponentialInsulinModelPreset.RawValue else {
                return nil
            }
            
            if let model = ExponentialInsulinModelPreset(rawValue: modelRaw) {
                self = .exponentialPreset(model)
            }
            
            switch modelRaw {
            case "rapidActingAdult":
                self = .exponentialPreset(ExponentialInsulinModelPreset.rapidActingAdult)
            case "rapidActingChild":
                self = .exponentialPreset(ExponentialInsulinModelPreset.rapidActingChild)
            default:
                return nil
            }
        default:
            return nil
        }
    }

    public var rawValue: [String : Any] {
        switch self {
        case .exponentialPreset(let model):
            return [
                "type": InsulinModelType.exponentialPreset.rawValue,
                "model": model.rawValue
            ]
        }
    }

    private enum InsulinModelType: String {
        case exponentialPreset
        case walsh
    }
}

public extension StoredInsulinModel {
    init(_ insulinModelSettings: InsulinModelSettings) {       
        var modelType: StoredInsulinModel.ModelType
        var actionDuration: TimeInterval
        var peakActivity: TimeInterval?
        
        switch insulinModelSettings {
        case .exponentialPreset(let preset):
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
        }
        
        self.init(modelType: modelType, actionDuration: actionDuration, peakActivity: peakActivity)
    }
}
