//
//  EmojiRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 8/1/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct EmojiRow<Row: Equatable>: View {
    private let emojiType: EmojiDataSourceType
    @Binding private var text: String
    private let title: String
    
    @Binding private var expandedRow: Row?
    private let row: Row
    
    public init(emojiType: EmojiDataSourceType, text: Binding<String>, title: String, expandedRow: Binding<Row?>, row: Row) {
        self.emojiType = emojiType
        self._text = text
        self.title = title
        self._expandedRow = expandedRow
        self.row = row
    }
    
    public var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            RowEmojiTextField(text: $text, placeholder: SettingsTableViewCell.NoValueString, expandedRow: $expandedRow, row: row, emojiType: emojiType)
        }
        .onTapGesture {
            rowTapped()
        }
    }
    
    private func rowTapped() {
        withAnimation {
            if expandedRow == row {
                expandedRow = nil
            }
            else {
                expandedRow = row
            }
        }
    }
}
