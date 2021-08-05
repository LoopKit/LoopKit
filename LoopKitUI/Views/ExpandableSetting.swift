//
//  ExpandableSetting.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct ExpandableSetting<
    LeadingValueContent: View,
    TrailingValueContent: View,
    ExpandedContent: View
>: View {
    @Binding var isEditing: Bool
    var leadingValueContent: LeadingValueContent
    var trailingValueContent: TrailingValueContent
    var expandedContent: () -> ExpandedContent

    public init(
        isEditing: Binding<Bool>,
        @ViewBuilder leadingValueContent: () -> LeadingValueContent,
        @ViewBuilder trailingValueContent: () -> TrailingValueContent,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent
    ) {
        self._isEditing = isEditing
        self.leadingValueContent = leadingValueContent()
        self.trailingValueContent = trailingValueContent()
        self.expandedContent = expandedContent
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                leadingValueContent

                Spacer()

                trailingValueContent
                    .fixedSize(horizontal: true, vertical: false)
            }
            .accessibilityElement(children: .combine)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    self.isEditing.toggle()
                }
            }

            if isEditing {
                expandedContent()
                    .padding(.horizontal, -8)
                    .transition(.fadeInFromTop)
            }
        }
    }
}

extension ExpandableSetting where LeadingValueContent == EmptyView {
    public init(
        isEditing: Binding<Bool>,
        @ViewBuilder valueContent: () -> TrailingValueContent,
        @ViewBuilder expandedContent: @escaping () -> ExpandedContent
    ) {
        self.init(isEditing: isEditing, leadingValueContent: EmptyView.init, trailingValueContent: valueContent, expandedContent: expandedContent)
    }
}
