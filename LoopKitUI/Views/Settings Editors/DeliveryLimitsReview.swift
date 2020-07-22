//
//  DeliveryLimitsReview.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/6/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit
import HealthKit


public struct DeliveryLimitsReview: View {
    @ObservedObject var viewModel: TherapySettingsViewModel
    let mode: PresentationMode
    
    public init(mode: PresentationMode = .acceptanceFlow, viewModel: TherapySettingsViewModel) {
        precondition(viewModel.pumpSupportedIncrements != nil)
        self.viewModel = viewModel
        self.mode = mode
    }
    
    @ViewBuilder public var body: some View {
        DeliveryLimitsEditor(
            value: DeliveryLimits(maximumBasalRate: maxBasal, maximumBolus: maxBolus),
            supportedBasalRates: viewModel.pumpSupportedIncrements!.basalRates,
            scheduledBasalRange: viewModel.therapySettings.basalRateSchedule?.valueRange(),
            supportedBolusVolumes: viewModel.pumpSupportedIncrements!.bolusVolumes,
            onSave: { limits in
                self.viewModel.saveDeliveryLimits(limits: limits)
        },
            mode: mode
        )
    }

    private var maxBasal: HKQuantity {
        return HKQuantity(unit: .internationalUnitsPerHour, doubleValue: viewModel.therapySettings.maximumBasalRatePerHour!)
    }
    
    private var maxBolus: HKQuantity {
        return HKQuantity(unit: .internationalUnit(), doubleValue: viewModel.therapySettings.maximumBolus!)
    }
}
