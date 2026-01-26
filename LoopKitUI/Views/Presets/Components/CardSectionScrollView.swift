//
//  CardSectionScrollView.swift
//  Loop
//
//  Created by Pete Schwamb on 3/7/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

// Container designed to hold CardSection views in a scrollview, and an optional action area
// that the scrollview would flow under, with a shadow effect. Together, they replace a List (TableView)
// with grouped styling, and allow rows to have their height animated as expected, avoiding the animation
// issues that resizing rows in Lists presents.

import SwiftUI

public struct CardSectionScrollView<Content: View, ActionArea: View>: View {
    let content: Content
    let actionArea: ActionArea?

    // Initializer for custom view header
    public init(@ViewBuilder content: () -> Content, @ViewBuilder actionArea: () -> ActionArea) {
        self.content = content()
        self.actionArea = actionArea()
    }

    // Initializer for no action area
    public init(@ViewBuilder content: () -> Content) where ActionArea == Text {
        self.content = content()
        self.actionArea = nil
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading) {
                    content
                }
                .padding()
            }
            if let actionArea {
                VStack(spacing: 12) {
                    actionArea
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemGroupedBackground).shadow(radius: 5))
            }
        }
        .background(Color(.systemGroupedBackground))
        .edgesIgnoringSafeArea(actionArea != nil ? .bottom : [])
    }
}
