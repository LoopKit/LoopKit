//
//  DeliveryLimits.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit

public struct DeliveryLimits: Equatable {
    public enum Setting: Equatable {
        case maximumBasalRate
        case maximumBolus
    }

    private var settings: [Setting: HKQuantity]

    public init(maximumBasalRate: HKQuantity?, maximumBolus: HKQuantity?) {
        settings = [:]
        settings[.maximumBasalRate] = maximumBasalRate
        settings[.maximumBolus] = maximumBolus
    }

    public var maximumBasalRate: HKQuantity? {
        get { settings[.maximumBasalRate] }
        set { settings[.maximumBasalRate] = newValue }
    }

    public var maximumBolus: HKQuantity? {
        get { settings[.maximumBolus] }
        set { settings[.maximumBolus] = newValue }
    }
}

public extension DeliveryLimits.Setting {
    // The following comes from https://tidepool.atlassian.net/browse/IFU-24
    var title: String {
        switch self {
        case .maximumBasalRate:
            return LocalizedString("Maximum Basal Rate", comment: "Title text for maximum basal rate configuration")
        case .maximumBolus:
            return LocalizedString("Maximum Bolus", comment: "Title text for maximum bolus configuration")
        }
    }
    
    var descriptiveText: String {
        switch self {
        case .maximumBasalRate:
            return LocalizedString("Maximum basal rate is the highest temporary basal rate Loop is allowed to set automatically.", comment: "Descriptive text for maximum basal rate")
        case .maximumBolus:
            return LocalizedString("Maximum bolus is the highest bolus amount you can deliver at one time to cover carbs or bring down high glucose.", comment: "Descriptive text for maximum bolus")
        }
    }
}

