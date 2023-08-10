//
//  TextFieldRow.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/31/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

public struct TextFieldRow<Row: Equatable>: View {
    @Binding private var text: String
    let title: String
    let placeholder: String
    
    @Binding private var expandedRow: Row?
    private let row: Row
    
    public init(text: Binding<String>, title: String, placeholder: String, expandedRow: Binding<Row?>, row: Row) {
        self._text = text
        self.title = title
        self.placeholder = placeholder
        self._expandedRow = expandedRow
        self.row = row
    }

    public var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            RowTextField(text: $text, expandedRow: $expandedRow, thisRow: row) {
                $0.textAlignment = .right
                $0.placeholder = placeholder
            }
        }
        .accessibilityElement(children: .combine)
        .onTapGesture {
            rowTapped()
        }
    }
    
    private func rowTapped() {
        withAnimation {
            expandedRow = nil
        }
    }
}
