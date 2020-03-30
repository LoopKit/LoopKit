//
//  GuideNavigationButton.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2020-03-04.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct GuideNavigationButton<Destination>: View where Destination: View {
    @Binding var navigationLinkIsActive: Bool
    private let label: String
    private let buttonPressedAction: (() -> Void)?
    private let buttonStyle: ActionButton.ButtonType
    private let destination: () -> Destination
    
    public init(navigationLinkIsActive: Binding<Bool>,
                label: String,
                buttonPressedAction: (() -> Void)? = nil,
                buttonStyle: ActionButton.ButtonType = .primary,
                @ViewBuilder destination: @escaping () -> Destination)
    {
        self._navigationLinkIsActive = navigationLinkIsActive
        self.label = label
        self.buttonPressedAction = buttonPressedAction
        self.buttonStyle = buttonStyle
        self.destination = destination
    }
    
    public var body: some View {
        NavigationLink(destination: destination(),
                       isActive: self.$navigationLinkIsActive)
        {
            Button(action: {
                self.buttonPressedAction?()
                self.navigationLinkIsActive = true
            }) {
                Text(label)
                    .actionButtonStyle(buttonStyle)
            }
        }
        .isDetailLink(false)
    }
}
