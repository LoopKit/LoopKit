//
//  EmojiRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 8/1/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct EmojiRow: View {
    @Binding private var text: String
    @Binding private var isFocused: Bool
    private let emojiType: EmojiDataSourceType
    private let title: String
    
    public init(text: Binding<String>, isFocused: Binding<Bool>, emojiType: EmojiDataSourceType, title: String) {
        self._text = text
        self._isFocused = isFocused
        self.emojiType = emojiType
        self.title = title
    }
    
    public var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            RowEmojiTextField(text: $text, isFocused: $isFocused, placeholder: SettingsTableViewCell.NoValueString, emojiType: emojiType)
                .onTapGesture {
                    // so that row does not lose focus on cursor move
                    if !isFocused {
                        rowTapped()
                    }
                }
        }
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
