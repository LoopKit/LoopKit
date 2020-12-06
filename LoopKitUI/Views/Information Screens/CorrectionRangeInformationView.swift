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
    var mode: SettingsPresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.appName) var appName

    public init(onExit: (() -> Void)? = nil, mode: SettingsPresentationMode = .acceptanceFlow) {
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        GlucoseTherapySettingInformationView(
            therapySetting: .glucoseTargetRange,
            onExit: onExit,
            mode: mode,
            appName: appName,
            text: AnyView(text)
        )
    }
    
    private var text: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(LocalizedString("If you've used a CGM before, you're likely familiar with target range as a wide range of values you'd like for your glucose notification alerts, such as 70-180 mg/dL or 90-200 mg/dL.", comment: "Information about target range"))
            Text(LocalizedString("A Correction Range is different. This will be a narrower range.", comment: "Information about differences between target range and correction range"))
            .bold()
            Text(String(format: LocalizedString("For this range, choose the specific glucose value (or range of values) that you want %1$@ to aim for in adjusting your basal insulin.", comment: "Information about correction range format (1: app name)"), appName))
            Text(LocalizedString("Your healthcare provider can help you choose a Correction Range that's right for you.", comment: "Disclaimer"))
        }
        .foregroundColor(.secondary)
    }
}

struct CorrectionRangeInformationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CorrectionRangeInformationView()
        }
        .colorScheme(.light)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE 2"))
        .previewDisplayName("SE light")
        NavigationView {
            CorrectionRangeInformationView()
        }
        .preferredColorScheme(.dark)
        .colorScheme(.dark)
        .previewDevice(PreviewDevice(rawValue: "iPhone 11 Pro Max"))
        .previewDisplayName("11 Pro dark")
    }
}
