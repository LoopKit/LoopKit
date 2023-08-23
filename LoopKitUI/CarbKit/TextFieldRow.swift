//
//  TextFieldRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/31/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct TextFieldRow: View {
    @Binding private var text: String
    @Binding private var isFocused: Bool
    
    let title: String
    let placeholder: String
    
    public init(text: Binding<String>, isFocused: Binding<Bool>, title: String, placeholder: String) {
        self._text = text
        self._isFocused = isFocused
        self.title = title
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            RowTextField(text: $text, isFocused: $isFocused) {
                $0.textAlignment = .right
                $0.placeholder = placeholder
                $0.font = .preferredFont(forTextStyle: .body)
            }
            .onTapGesture {
                // so that row does not lose focus on cursor move
                if !isFocused {
                    rowTapped()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .onTapGesture {
            rowTapped()
        }
    }
    
    private func rowTapped() {
        withAnimation {
            isFocused.toggle()
        }
    }
}
