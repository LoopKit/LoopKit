//
//  InformationView.swift
//  LoopKitUI
//
//  Created by Anna Quinlan on 7/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

struct InformationView<InformationalContent: View> : View {
    var informationalContent: InformationalContent
    var title: Text
    var buttonText: Text
    var onExit: (() -> Void)
    let mode: SettingsPresentationMode
    
    init(
        title: Text,
        buttonText: Text,
        @ViewBuilder informationalContent: () -> InformationalContent,
        onExit: @escaping () -> Void,
        mode: SettingsPresentationMode
    ) {
        self.title = title
        self.buttonText = buttonText
        self.informationalContent = informationalContent()
        self.onExit = onExit
        self.mode = mode
    }
    
    // Convenience initializer for info view w/next page button
    init(
        title: Text,
        @ViewBuilder informationalContent: () -> InformationalContent,
        onExit: @escaping () -> Void,
        mode: SettingsPresentationMode = .acceptanceFlow
    ) {
        self.init(
            title: title,
            buttonText: Text(LocalizedString("Continue", comment: "Button to advance to setting editor")),
            informationalContent: informationalContent,
            onExit: onExit,
            mode: mode
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                bodyForMode
                    .padding()
                    .frame(minHeight: geometry.size.height)
            }
        }
    }

    @ViewBuilder
    private var bodyForMode: some View {
        switch mode {
        case .acceptanceFlow:
            bodyForAcceptanceFlow
        case .settings:
            bodyForSettings
        }
    }
    
    private var bodyForAcceptanceFlow: some View {
        VStack(alignment: .leading, spacing: 20) {
            titleView
            Divider()
            informationalContent
            Spacer()
            nextPageButton
        }
    }
    
    private var bodyForSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            informationalContent
            Spacer()
        }
        .navigationBarItems(trailing: cancelButton)
        .navigationBarTitle(title, displayMode: .large)
    }

    private var titleView: some View {
        title
            .font(.largeTitle)
            .bold()
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var cancelButton: some View {
        Button(action: onExit, label: { Text(LocalizedString("Close", comment: "Text to close informational page")) })
    }
    
    private var nextPageButton: some View {
        Button(action: onExit) {
            buttonText
            .actionButtonStyle(.primary)
        }
    }
}
