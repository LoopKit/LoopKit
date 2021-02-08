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
        ScrollView {
            bodyWithCancelButtonIfNeeded
            .navigationBarTitle(title, displayMode: .large)
            .padding()
        }
    }
    
    private var bodyWithCancelButtonIfNeeded: some View {
        switch mode {
        case .acceptanceFlow:
            return AnyView(bodyWithBottomButton)
        case .settings:
            return AnyView(bodyWithCancelButton)
        }
    }
    
    private var bodyWithBottomButton: some View {
        VStack(alignment: .leading, spacing: 20) {
            informationalContent
            Spacer()
            nextPageButton
        }
    }
    
    private var bodyWithCancelButton: some View {
        VStack(alignment: .leading, spacing: 20) {
            informationalContent
            Spacer()
        }
        .navigationBarItems(trailing: cancelButton)
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
