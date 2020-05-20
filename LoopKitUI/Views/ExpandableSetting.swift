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
    ValuePicker: View
>: View {
    @Binding var isEditing: Bool
    var leadingValueContent: LeadingValueContent
    var trailingValueContent: TrailingValueContent
    var valuePicker: ValuePicker

    public init(
        isEditing: Binding<Bool>,
        @ViewBuilder leadingValueContent: () -> LeadingValueContent,
        @ViewBuilder trailingValueContent: () -> TrailingValueContent,
        @ViewBuilder valuePicker: () -> ValuePicker
    ) {
        self._isEditing = isEditing
        self.leadingValueContent = leadingValueContent()
        self.trailingValueContent = trailingValueContent()
        self.valuePicker = valuePicker()
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                leadingValueContent
                Spacer()
                trailingValueContent
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    self.isEditing.toggle()
                }
            }

            if isEditing {
                valuePicker
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
        @ViewBuilder valuePicker: () -> ValuePicker
    ) {
        self.init(isEditing: isEditing, leadingValueContent: EmptyView.init, trailingValueContent: valueContent, valuePicker: valuePicker)
    }
}
