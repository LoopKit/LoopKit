//
//  TherapySetting.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//


public enum TherapySetting: Int {
    case glucoseTargetRange
    case correctionRangeOverrides
    case suspendThreshold
    case basalRate
    case deliveryLimits
    case insulinModel
    case carbRatio
    case insulinSensitivity
    case none
}

public extension TherapySetting {
    
    // The following comes from https://tidepool.atlassian.net/browse/IFU-24
    var title: String {
        switch self {
        case .glucoseTargetRange:
            return LocalizedString("Correction Range", comment: "Title text for glucose target range")
        case .correctionRangeOverrides:
            return LocalizedString("Temporary Correction Ranges", comment: "Title text for temporary correction ranges")
        case .suspendThreshold:
            return LocalizedString("Suspend Threshold", comment: "Title text for suspend threshold")
        case .basalRate:
            return LocalizedString("Basal Rate", comment: "Title text for basal rate")
        case .deliveryLimits:
            return LocalizedString("Delivery Limits", comment: "Title text for delivery limits")
        case .insulinModel:
            return LocalizedString("Insulin Model", comment: "Title text for insulin model")
        case .carbRatio:
            return LocalizedString("Carb Ratios", comment: "Title text for carb ratios")
        case .insulinSensitivity:
            return LocalizedString("Insulin Sensitivities", comment: "Title text for insulin sensitivity")
        case .none:
            return ""
        }
    }
    
    var smallTitle: String {
        switch self {
        case .correctionRangeOverrides:
            return LocalizedString("Temporary Ranges", comment: "Title text for temporary correction ranges")
        default:
            return title
        }
    }
    
    var descriptiveText: String {
        switch self {
        case .glucoseTargetRange:
            return LocalizedString("Correction range is the glucose value (or range of values) that you want Tidepool Loop to aim for in adjusting your basal insulin.", comment: "Descriptive text for glucose target range")
        case .correctionRangeOverrides:
            return LocalizedString("Pre-Meal and Workout ranges temporarily adjust your glucose target based on your selected activity.", comment: "Descriptive text for correction range overrides")
        case .suspendThreshold:
            return LocalizedString("When your glucose is predicted to go below this value, the app will recommend a basal rate of 0 U/hr and will not recommend a bolus.", comment: "Descriptive text for suspend threshold")
        case .basalRate:
            return LocalizedString("Your basal rate of insulin is the number of units per hour that you want to use to cover your background insulin needs.", comment: "Descriptive text for basal rate")
        case .deliveryLimits:
            return "\(DeliveryLimits.Setting.maximumBasalRate.descriptiveText)\n\n\(DeliveryLimits.Setting.maximumBolus.descriptiveText)"
        case .insulinModel:
            return LocalizedString("The app assumes insulin is actively working for 6 hours. You can choose from different models for how the app measures the insulin’s peak activity.", comment: "Descriptive text for insulin model")
        case .carbRatio:
            return LocalizedString("Your carb ratio is the number of grams of carbohydrate covered by one unit of insulin.", comment: "Descriptive text for carb ratio")
        case .insulinSensitivity:
            return LocalizedString("Your insulin sensitivities refer to the drop in glucose expected from one unit of insulin.", comment: "Descriptive text for insulin sensitivity")
        case .none:
            return ""
        }
    }
}
