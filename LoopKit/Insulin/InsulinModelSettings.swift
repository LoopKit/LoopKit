//
//  InsulinModelSettings.swift
//  LoopKit
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

public enum InsulinModelSettings: Equatable {
    case exponentialPreset(ExponentialInsulinModelPreset)
    case walsh(WalshInsulinModel)

    public static let validWalshModelDurationRange = TimeInterval(hours: 2)...TimeInterval(hours: 8)
    
    public var longestEffectDuration: TimeInterval {
        switch self {
        case .exponentialPreset(let model):
            return model.effectDuration
        case .walsh(let model):
            return model.effectDuration
        }
    }

    public func model(for type: InsulinType?) -> InsulinModel {
        guard let type = type else {
            return ExponentialInsulinModelPreset.rapidActingAdult
        }
        
        switch type {
        case .fiasp:
            return ExponentialInsulinModelPreset.fiasp
        default:
            switch self {
            case .exponentialPreset(let model):
                return model
            case .walsh(let model):
                return model
            }
        }
    }

    public init?(model: InsulinModel) {
        switch model {
        case let model as ExponentialInsulinModelPreset:
            self = .exponentialPreset(model)
        case let model as WalshInsulinModel:
            self = .walsh(model)
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
            let walsh =  try container.decode(WalshInsulinModel.self, forKey: .walsh)
            self = .walsh(walsh)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .exponentialPreset(let model):
            try container.encode(model, forKey: .exponential)
        case .walsh(let model):
            try container.encode(model, forKey: .walsh)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case exponential
        case walsh
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

        case .walsh:
            guard let modelRaw = rawValue["model"] as? WalshInsulinModel.RawValue,
                let model = WalshInsulinModel(rawValue: modelRaw)
            else {
                return nil
            }

            self = .walsh(model)
        }
    }

    public var rawValue: [String : Any] {
        switch self {
        case .exponentialPreset(let model):
            return [
                "type": InsulinModelType.exponentialPreset.rawValue,
                "model": model.rawValue
            ]
        case .walsh(let model):
            return [
                "type": InsulinModelType.walsh.rawValue,
                "model": model.rawValue
            ]
        }
    }

    private enum InsulinModelType: String {
        case exponentialPreset
        case walsh
    }
}

public extension InsulinModelSettings {
    init(from storedSettingsInsulinModel: StoredInsulinModel) {
        switch storedSettingsInsulinModel.modelType {
        case .fiasp:
            self = .exponentialPreset(.fiasp)
        case .rapidAdult:
            self = .exponentialPreset(.rapidActingAdult)
        case .rapidChild:
            self = .exponentialPreset(.rapidActingChild)
        case .walsh:
            self = .walsh(WalshInsulinModel(actionDuration: storedSettingsInsulinModel.actionDuration))
        }
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
        case .walsh(let model):
            modelType = .walsh
            actionDuration = model.actionDuration
        }
        
        self.init(modelType: modelType, actionDuration: actionDuration, peakActivity: peakActivity)
    }
}
