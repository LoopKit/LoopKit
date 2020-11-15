//
//  SuspendThresholdInformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct SuspendThresholdInformationView: View {
    var onExit: (() -> Void)?
    var mode: PresentationMode
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.appName) private var appName

    public init(
        onExit: (() -> Void)?,
        mode: PresentationMode = .acceptanceFlow
    ){
        self.onExit = onExit
        self.mode = mode
    }
    
    public var body: some View {
        InformationView(
            title: Text(TherapySetting.suspendThreshold.title),
            informationalContent: {text},
            onExit: onExit ?? { self.presentationMode.wrappedValue.dismiss() },
            mode: mode
        )
    }
    
    private var text: some View {
        VStack(alignment: .leading, spacing: 25) {
            Text(TherapySetting.suspendThreshold.descriptiveText(appName: appName))
        }
        .accentColor(.secondary)
        .foregroundColor(.accentColor)
    }
}
