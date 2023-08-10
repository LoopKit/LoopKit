//
//  RowEmojiTextField.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 8/1/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// Has the same functions as `RowTextField` and uses an `EmojiInputController` as the keyboard. This struct handles `standardInputMode` as well.
struct RowEmojiTextField<Row: Equatable>: View {
    @Binding private var text: String
    private var placeholder: String
    
    @Binding private var expandedRow: Row?
    private let row: Row
    
    private let emojiType: EmojiDataSourceType
    
    @StateObject private var viewModel: EmojiTextFieldViewModel
    
    class EmojiTextFieldViewModel: ObservableObject, EmojiInputControllerDelegate {
        @Published var standardInputMode = false
        let didSelectItemInSection: ((Int) -> Void)?
        
        init(didSelectItemInSection: ((Int) -> Void)?) {
            self.didSelectItemInSection = didSelectItemInSection
        }
        
        func emojiInputControllerDidAdvanceToStandardInputMode(_ controller: EmojiInputController) {
            self.standardInputMode = true
        }
        
        func emojiInputControllerDidSelectItemInSection(_ section: Int) {
            didSelectItemInSection?(section)
        }
    }
    
    init(text: Binding<String>, placeholder: String = "", expandedRow: Binding<Row?>, row: Row, emojiType: EmojiDataSourceType, didSelectItemInSection: ((Int) -> Void)? = nil) {
        self._text = text
        self.placeholder = placeholder
        self._expandedRow = expandedRow
        self.row = row
        self.emojiType = emojiType
        self._viewModel = StateObject(wrappedValue: EmojiTextFieldViewModel(didSelectItemInSection: didSelectItemInSection))
    }
    
    var body: some View {
        // this if statement cannot be moved into the RowTextField closure because the closure does not refresh on state changes
        if viewModel.standardInputMode {
            RowTextField(text: $text, expandedRow: $expandedRow, thisRow: row, maxLength: 16) { textField in
                textField.textAlignment = .right
                textField.font = UIFont.preferredFont(forTextStyle: .title3)
                textField.autocorrectionType = .no
                textField.autocapitalizationType = .none
                textField.placeholder = placeholder
            }
        }
        else {
            RowTextField(text: $text, expandedRow: $expandedRow, thisRow: row, maxLength: 16) { textField in
                textField.textAlignment = .right
                textField.font = UIFont.preferredFont(forTextStyle: .title3)
                let emojiController = EmojiInputController.instance(withEmojis: emojiType.dataSource())
                emojiController.delegate = viewModel
                textField.customInput = emojiController
                textField.placeholder = placeholder
            }
        }
    }
}
