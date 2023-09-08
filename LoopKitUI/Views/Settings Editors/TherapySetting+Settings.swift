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
    
    @ViewBuilder
    public func helpScreen() -> some View {
        switch self {
        case .glucoseTargetRange:
            CorrectionRangeInformationView(onExit: nil, mode: .settings)
        case .preMealCorrectionRangeOverride:
            CorrectionRangeOverrideInformationView(preset: .preMeal, onExit: nil, mode: .settings)
        case .workoutCorrectionRangeOverride:
            CorrectionRangeOverrideInformationView(preset: .workout, onExit: nil, mode: .settings)
        case .suspendThreshold:
            SuspendThresholdInformationView(onExit: nil, mode: .settings)
        case .basalRate(let maximumScheduleEntryCount):
            BasalRatesInformationView(onExit: nil, mode: .settings, maximumScheduleEntryCount: maximumScheduleEntryCount)
        case .deliveryLimits:
            DeliveryLimitsInformationView(onExit: nil, mode: .settings)
        case .insulinModel:
            InsulinModelInformationView(onExit: nil, mode: .settings)
        case .carbRatio:
            CarbRatioInformationView(onExit: nil, mode: .settings)
        case .insulinSensitivity:
            InsulinSensitivityInformationView(onExit: nil, mode: .settings)
        case .none:
            Text("To be implemented")
        }
    }
}

