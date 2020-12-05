//
//  BasalRatesInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/3/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct BasalRatesInformationView: View {
    var onExit: (() -> Void)?
    var mode: SettingsPresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(onExit: (() -> Void)?, mode: SettingsPresentationMode = .acceptanceFlow) {
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(TherapySetting.basalRate.title),
            informationalContent: {text},
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var text: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(LocalizedString("Your Basal Rate of insulin is the number of units per hour that you want to use to cover your background insulin needs.", comment: "Information about basal rates"))
            Text(LocalizedString("Loop supports 1 to 48 rates per day.", comment: "Information about max number of basal rates"))
            Text(LocalizedString("The schedule starts at midnight and cannot contain a rate of 0 U/hr.", comment: "Information about basal rate scheduling"))
        }
        .foregroundColor(.secondary)
    }
}
