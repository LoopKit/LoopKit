//
//  TherapySetting.swift
//  LoopKit
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//


public enum TherapySetting: Int {
    case glucoseTargetRange
    case preMealCorrectionRangeOverride
    case workoutCorrectionRangeOverride
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
        case .preMealCorrectionRangeOverride:
            return String(format: LocalizedString("%@ Range", comment: "Format for correction range override therapy setting card"), CorrectionRangeOverrides.Preset.preMeal.title)
        case .workoutCorrectionRangeOverride:
            return String(format: LocalizedString("%@ Range", comment: "Format for correction range override therapy setting card"), CorrectionRangeOverrides.Preset.workout.title)
        case .suspendThreshold:
            return LocalizedString("Suspend Threshold", comment: "Title text for suspend threshold")
        case .basalRate:
            return LocalizedString("Basal Rates", comment: "Title text for basal rates")
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
        default:
            return title
        }
    }
    
    var descriptiveText: String {
        switch self {
        case .glucoseTargetRange:
            return LocalizedString("Correction range is the glucose value (or range of values) that you want Loop to aim for in adjusting your basal insulin.", comment: "Descriptive text for glucose target range")
        case .preMealCorrectionRangeOverride:
            return LocalizedString("Temporarily lower your glucose target before a meal to impact post-meal glucose spikes.", comment: "Descriptive text for pre-meal correction range override")
        case .workoutCorrectionRangeOverride:
            return LocalizedString("Temporarily raise your glucose target before, during, or after physical activity to reduce the risk of low glucose events.", comment: "Descriptive text for workout correction range override")
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

// MARK: Guardrails
public extension TherapySetting {
    var guardrailCaptionForLowValue: String {
        switch self {
        // For schedules & ranges where it's possible for more than 1 to be outside of guardrails
        case .glucoseTargetRange:
            return LocalizedString("A value you have entered is lower than what is typically recommended for most people.", comment: "Descriptive text for guardrail low value warning for schedule interface")
        default:
            return LocalizedString("The value you have entered is lower than what is typically recommended for most people.", comment: "Descriptive text for guardrail low value warning")
        }
    }
    
    var guardrailCaptionForHighValue: String {
        switch self {
        // For schedules & ranges where it's possible for more than 1 to be outside of guardrails
        case .glucoseTargetRange:
            return LocalizedString("A value you have entered is higher than what is typically recommended for most people.", comment: "Descriptive text for guardrail high value warning for schedule interface")
        default:
            return LocalizedString("The value you have entered is higher than what is typically recommended for most people.", comment: "Descriptive text for guardrail high value warning")
        }
    }
    
    var guardrailCaptionForOutsideValues: String {
        switch self {
        case .deliveryLimits:
            return LocalizedString("The values you have entered are outside of what is typically recommended for most people.", comment: "Descriptive text for guardrail high value warning")
        default:
            return LocalizedString("Some of the values you have entered are outside of what is typically recommended for most people.", comment: "Descriptive text for guardrail high value warning for schedule interface")
        }
    }
    
    var guardrailSaveWarningCaption: String {
        switch self {
        default:
            return LocalizedString("One or more of the values you have entered is outside of what is typically recommended for most people.", comment: "Descriptive text for saving settings outside the recommended range")
        }
    }
}
