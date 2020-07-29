//
//  CorrectionRangeInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct CorrectionRangeInformationView: View {
    var onExit: (() -> Void)?
    var mode: PresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(onExit: (() -> Void)?, mode: PresentationMode = .acceptanceFlow) {
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(TherapySetting.glucoseTargetRange.title),
            informationalContent: {text},
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var text: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(LocalizedString("If you've used a CGM before, you're likely familiar with target range as a wide range of values you'd like for your glucose notification alerts, such as 70-180 mg/dL or 90-200 mg/dL.", comment: "Information about target range"))
            Text(LocalizedString("A correction range is different. This will be a narrower range.", comment: "Information about differences between target range and correction range"))
            .bold()
            Text(LocalizedString("For this range, choose the specific glucose value (or range of values) that you want Tidepool Loop to aim for in adjusting your basal insulin.", comment: "Information about correction range"))
            Text(LocalizedString("Your healthcare provider can help you choose a correction range that's right for you.", comment: "Disclaimer"))
        }
        .foregroundColor(.secondary)
    }
}
