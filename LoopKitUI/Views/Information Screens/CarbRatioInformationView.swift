//
//  CarbRatioInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/28/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct CarbRatioInformationView: View {
    var onExit: (() -> Void)?
    var mode: PresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(
        onExit: (() -> Void)?,
        mode: PresentationMode = .acceptanceFlow
    ){
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(TherapySetting.carbRatio.title),
            informationalContent: {text},
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var text: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(TherapySetting.carbRatio.descriptiveText)
            Text(LocalizedString("You can add different carb ratios for different times of day by using the ➕.", comment: "Description of how to add a ratio"))
        }
        .accentColor(.secondary)
        .foregroundColor(.accentColor)
    }
}
