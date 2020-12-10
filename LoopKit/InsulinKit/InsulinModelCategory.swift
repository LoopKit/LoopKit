//
//  InsulinModelCategory.swift
//  LoopKit
//
//  Created by Anna Quinlan on 12/8/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum InsulinModelCategory: Int, Codable {
    case none = 0
    case rapidActing
    case fiasp
    
    public var title: String {
        switch self {
        case .none:
            return LocalizedString("No Associated Model", comment: "No insulin model")
        case .rapidActing:
            return LocalizedString("Rapid Acting", comment: "Rapid acting insulin model")
        case .fiasp:
            return LocalizedString("Fiasp", comment: "Fiasp insulin model")
        }
    }
}

// Used to keep track of insulin model information for the purposes of matching an InsulinModelCategory with the appropriate InsulinModel
public class InsulinModelInformation {
    let defaultInsulinModel: InsulinModel
    let rapidActingModel: InsulinModel
    
    public init (defaultInsulinModel: InsulinModel, rapidActingModel: InsulinModel? = nil) {
        self.defaultInsulinModel = defaultInsulinModel
        self.rapidActingModel = rapidActingModel ?? ExponentialInsulinModelPreset.humalogNovologAdult
    }
    
    func insulinModel(for category: InsulinModelCategory?) -> InsulinModel {
        guard let category = category else {
            return defaultInsulinModel
        }
        
        switch category {
        case .none:
            return defaultInsulinModel
        case .rapidActing:
            return rapidActingModel
        case .fiasp:
            return ExponentialInsulinModelPreset.fiasp
        }
    }
}

extension InsulinModelSettings {
    var insulinModelCategory: InsulinModelCategory {
        switch self {
        case .exponentialPreset(let model):
            switch model {
            case .fiasp:
                return .fiasp
            default:
                return .rapidActing
            }
        case .walsh:
            return .rapidActing
        }
    }
}
