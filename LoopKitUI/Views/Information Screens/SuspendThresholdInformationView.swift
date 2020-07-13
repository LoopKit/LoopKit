//
//  SuspendThresholdInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct SuspendThresholdInformationView: View {
    var onExit: (() -> Void)?
    var mode: PresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    
    public init(
        onExit: (() -> Void)?,
        mode: PresentationMode = .flow
    ){
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(LocalizedString("Suspend Threshold", comment: "Title for suspend threshold informational screen")),
            buttonText: Text(LocalizedString("Next: Review Setting", comment: "Button to advance to setting editor")),
            informationalContent: {text},
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var text: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(LocalizedString("When your glucose is predicted to go below this value, the app will recommend a basal rate of 0 U/hr and will not recommend a bolus.", comment: "Information about suspend threshold"))
        }
        .accentColor(.secondary)
        .foregroundColor(.accentColor)
    }
}
