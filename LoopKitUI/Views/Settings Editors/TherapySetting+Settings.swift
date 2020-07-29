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
    
    public func helpScreen() -> some View {
        switch self {
        case .glucoseTargetRange:
            return AnyView(CorrectionRangeInformationView(onExit: nil, mode: .settings))
        case .correctionRangeOverrides:
            return AnyView(CorrectionRangeOverrideInformationView(onExit: nil, mode: .settings))
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
        // ANNA TODO: add more once other instructional screens are created
        default:
            return AnyView(Text("To be implemented"))
        }
    }
}

