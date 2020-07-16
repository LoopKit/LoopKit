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
            return AnyView(CorrectionRangeInformationView(onExit: nil, mode: .modal))
        case .correctionRangeOverrides:
            return AnyView(CorrectionRangeOverrideInformationView(onExit: nil, mode: .modal))
        case .suspendThreshold:
            return AnyView(SuspendThresholdInformationView(onExit: nil, mode: .modal))
        case .basalRate:
            return AnyView(BasalRatesInformationView(onExit: nil, mode: .modal))
        case .deliveryLimits:
            return AnyView(DeliveryLimitsInformationView(onExit: nil, mode: .modal))
        // ANNA TODO: add more once other instructional screens are created
        default:
            return AnyView(Text("To be implemented"))
        }
    }
}

