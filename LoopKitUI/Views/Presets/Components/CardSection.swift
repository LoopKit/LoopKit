//
//  CardSection.swift
//  Loop
//
//  Created by Pete Schwamb on 3/6/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

// Simple rounded card view with arbitrary content. Can be used to make screens that look like grouped section table views,
// that need to animate height (List/TableViews have problems with resizing views and animating them). Similar to Card in
// LoopKitUI, but unlike Card, has requirement on the type of content except that it is a View.

public struct CardSection<Content: View, Header: View, Footer: View>: View {
    let header: Header?
    let footer: Footer?
    let content: Content
    
    let borderColor: Color

    // Initializer for custom view header
    public init(borderColor: Color = .clear, @ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header, @ViewBuilder footer: () -> Footer) {
        self.borderColor = borderColor
        self.content = content()
        self.header = header()
        self.footer = footer()
    }

    // Initializer for string header
    public init(_ headerText: String? = nil, borderColor: Color = .clear, @ViewBuilder content: () -> Content, footerText: String? = nil) where Header == Text, Footer == Text {
        self.borderColor = borderColor
        self.content = content()
        self.header = headerText.map { Text($0) }
        self.footer = footerText.map { Text($0) }
    }

    // Initializer for no header
    public init(borderColor: Color = .clear, @ViewBuilder content: () -> Content) where Header == Text, Footer == Text {
        self.borderColor = borderColor
        self.content = content()
        self.header = nil
        self.footer = nil
    }

    public var body: some View {
        VStack(alignment: .leading) {
            if let header = header {
                header
                    .font(.footnote)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            VStack {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.tertiarySystemBackground))
                .stroke(borderColor, lineWidth: borderColor == .clear ? 0 : 1)
                .frame(maxWidth: .infinity))
            if let footer = footer {
                footer
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.leading)
            }
        }
        .padding(.top, 10)
    }
}

