//
//  DeliveryLimitsInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct DeliveryLimitsInformationView: View {
    var onExit: (() -> Void)?
    var mode: SettingsPresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.appName) var appName

    public init(onExit: (() -> Void)?, mode: SettingsPresentationMode = .acceptanceFlow) {
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(TherapySetting.deliveryLimits.title),
            informationalContent: {
                VStack (alignment: .leading, spacing: 20) {
                    deliveryLimitDescription
                    maxBasalDescription
                    maxBolusDescription
                }
                .fixedSize(horizontal: false, vertical: true) // prevent text from being cut off
            },
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var deliveryLimitDescription: some View {
        Text(LocalizedString("Delivery Limits are safety guardrails for your insulin delivery.", comment: "Information about delivery limits"))
        .foregroundColor(.secondary)
    }
    
    private var maxBasalDescription: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(DeliveryLimits.Setting.maximumBasalRate.title)
            .font(.headline)
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedString("Maximum Basal Rate is the maximum automatically adjusted basal rate that \(appName) is allowed to enact to help reach your correction range.", comment: "Information about maximum basal rate"))
                Text(LocalizedString("Some users choose a value 2, 3, or 4 times their highest scheduled basal rate.", comment: "Information about typical maximum basal rates"))
                Text(LocalizedString("Work with your healthcare provider to choose a value that is higher than your highest scheduled basal rate, but as conservative or aggressive as you feel comfortable.", comment: "Disclaimer"))
            }
            .foregroundColor(.secondary)
        }
    }
    
    private var maxBolusDescription: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(DeliveryLimits.Setting.maximumBolus.title)
            .font(.headline)
            Text(LocalizedString("Maximum Bolus is the highest bolus amount that you will allow \(appName) to recommend at one time to cover carbs or bring down high glucose.", comment: "Information about maximum bolus"))
            .foregroundColor(.secondary)
        }
    }
}

