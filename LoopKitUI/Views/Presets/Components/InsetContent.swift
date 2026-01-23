//
//  InsetContent.swift
//  Loop
//
//  Created by Cameron Ingham on 8/26/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct InsetContent<Content: View>: View {
    
    let alignment: HorizontalAlignment
    let spacing: Double
    let padding: Double
    let content: Content
    
    public init(alignment: HorizontalAlignment = .center, spacing: Double = 24, padding: Double = 16, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.padding = padding
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.gray.quinary, lineWidth: 1)
        )
    }
}
