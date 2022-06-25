//
//  SettingDescription.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct SettingDescription<InformationalContent: View>: View {
    var text: Text
    var informationalContent: InformationalContent
    @State var displayHelpPage: Bool = false

    public init(
        text: Text,
        @ViewBuilder informationalContent: @escaping () -> InformationalContent
    ) {
        self.text = text
        self.informationalContent = informationalContent()
    }

    public var body: some View {
        HStack(spacing: 8) {
            text
                .font(.callout)
                .foregroundColor(Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
            
            infoButton
            .sheet(isPresented: $displayHelpPage) {
                NavigationView {
                    self.informationalContent
                }
            }
        }
    }
    
    private var infoButton: some View {
        Button(
            action: {
                self.displayHelpPage = true
            },
            label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 25))
                    .foregroundColor(.accentColor)
            }
        )
        .accessibilityLabel("info")
        .padding(.trailing, 4)
    }
}
