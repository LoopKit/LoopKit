//
//  ActionButton.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 2020-03-04.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

// TODO: Migrate use sites to ActionButtonStyle
public struct ActionButton: ViewModifier {
    private let fontColor: Color
    private let backgroundColor: Color
    private let edgeColor: Color
    private let cornerRadius: CGFloat = 10
    
    public enum ButtonType {
        case primary
        case secondary
        case destructive
        case deactivated
    }
    
    init(_ style: ButtonType = .primary) {
        switch style {
        case .primary:
            fontColor = .white
            backgroundColor = .accentColor
            edgeColor = .clear
        case .destructive:
            fontColor = .white
            backgroundColor = .red
            edgeColor = .clear
        case .secondary:
            fontColor = .accentColor
            backgroundColor = .clear
            edgeColor = .accentColor
        case .deactivated:
            fontColor = .white
            backgroundColor = .gray
            edgeColor = .clear
        }
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(.all)
            .foregroundColor(fontColor)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(edgeColor))
    }
}

public extension View {
    func actionButtonStyle(_ style: ActionButton.ButtonType = .primary) -> some View {
        ModifiedContent(content: self, modifier: ActionButton(style))
    }
}
