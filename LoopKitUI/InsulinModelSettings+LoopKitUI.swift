//
//  InsulinModelSettings+Loop.swift
//  LoopKitUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit


public extension InsulinModelSettings {
    var title: String {
        switch self {
        case .exponentialPreset(let model):
            return model.title
        case .walsh(let model):
            return model.title
        }
    }
    var subtitle: String {
        switch self {
        case .exponentialPreset(let model):
            return model.subtitle
        case .walsh(let model):
            return model.subtitle
        }
    }
}


public extension ExponentialInsulinModelPreset {
    var title: String {
        switch self {
        case .humalogNovologAdult:
            return LocalizedString("Rapid-Acting – Adults", comment: "Title of insulin model preset - rapid acting adult")
        case .humalogNovologChild:
            return LocalizedString("Rapid-Acting – Children", comment: "Title of insulin model preset - rapid acting children")
        case .fiasp:
            return LocalizedString("Fiasp", comment: "Title of insulin model preset - fiasp")
        }
    }

    var subtitle: String {
        switch self {
        case .humalogNovologAdult:
            return LocalizedString("This model assumes peak insulin activity at 75 minutes.", comment: "Subtitle of Rapid-Acting – Adult preset")
        case .humalogNovologChild:
            return LocalizedString("This model assumes peak insulin activity at 65 minutes.", comment: "Subtitle of Rapid-Acting – Children preset")
        case .fiasp:
            return LocalizedString("This model assumes peak insulin activity at 55 minutes.", comment: "Subtitle of Fiasp preset")
        }
    }
}


public extension WalshInsulinModel {
    static var title: String {
        return LocalizedString("Walsh", comment: "Title of insulin model setting")
    }
    
    var title: String {
        return Self.title
    }

    static var subtitle: String {
        return LocalizedString("The legacy model used by Loop, allowing customization of action duration.", comment: "Subtitle description of Walsh insulin model setting")
    }
    
    var subtitle: String {
        return Self.subtitle
    }
}
