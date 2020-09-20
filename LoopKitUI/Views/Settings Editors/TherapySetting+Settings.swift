//
//  TherapySetting+Settings.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

extension TherapySetting {
    
    public var authenticationChallengeDescription: String {
        switch self {
        default:
            // Currently, this is the same no matter what the setting is.
            return LocalizedString("Authenticate to save therapy setting", comment: "Authentication hint string for therapy settings")
        }
    }
    
    public func helpScreen() -> some View {
        switch self {
        case .glucoseTargetRange:
            return AnyView(CorrectionRangeInformationView(onExit: nil, mode: .settings))
        case .preMealCorrectionRangeOverride:
            return AnyView(CorrectionRangeOverrideInformationView(preset: .preMeal, onExit: nil, mode: .settings))
        case .workoutCorrectionRangeOverride:
            return AnyView(CorrectionRangeOverrideInformationView(preset: .workout, onExit: nil, mode: .settings))
        case .suspendThreshold:
            return AnyView(SuspendThresholdInformationView(onExit: nil, mode: .settings))
        case .basalRate:
            return AnyView(BasalRatesInformationView(onExit: nil, mode: .settings))
        case .deliveryLimits:
            return AnyView(DeliveryLimitsInformationView(onExit: nil, mode: .settings))
        case .insulinModel:
            return AnyView(InsulinModelInformationView(onExit: nil, mode: .settings))
        case .carbRatio:
            return AnyView(CarbRatioInformationView(onExit: nil, mode: .settings))
        case .insulinSensitivity:
            return AnyView(InsulinSensitivityInformationView(onExit: nil, mode: .settings))
        case .none:
            return AnyView(Text("To be implemented"))
        }
    }
}

