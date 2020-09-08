//
//  ActionButtonStyle.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct ActionButtonStyle: ButtonStyle {
    public enum ButtonType {
        case primary
        case secondary
        case destructive
    }

    private let fontColor: Color
    private let backgroundColor: Color
    private let edgeColor: Color
    private let cornerRadius: CGFloat = 10
    private let squidge: CGFloat = 1

    public init(_ style: ButtonType = .primary) {
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
        }
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(configuration.isPressed ? -squidge : 0)
            .padding()
            .foregroundColor(fontColor)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .overlay(Color(.secondarySystemBackground).opacity(configuration.isPressed ? 0.35 : 0))
            .cornerRadius(cornerRadius)
            .padding(configuration.isPressed ? squidge : 0)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(edgeColor))
            .contentShape(Rectangle())
    }
}
