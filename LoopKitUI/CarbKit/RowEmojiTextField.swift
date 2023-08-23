//
//  RowEmojiTextField.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 8/1/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// Has the same functions as `RowTextField` and uses an `EmojiInputController` as the keyboard. This struct handles `standardInputMode` as well.
struct RowEmojiTextField: View {
    @Binding private var text: String
    @Binding private var isFocused: Bool
    
    private var placeholder: String
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
    
    init(text: Binding<String>, isFocused: Binding<Bool>, placeholder: String = "", emojiType: EmojiDataSourceType, didSelectItemInSection: ((Int) -> Void)? = nil) {
        self._text = text
        self._isFocused = isFocused
        self.placeholder = placeholder
        self.emojiType = emojiType
        self._viewModel = StateObject(wrappedValue: EmojiTextFieldViewModel(didSelectItemInSection: didSelectItemInSection))
    }
    
    var body: some View {
        // this if statement cannot be moved into the RowTextField closure because the closure does not refresh on state changes
        if viewModel.standardInputMode {
            RowTextField(text: $text, isFocused: $isFocused, maxLength: 20) { textField in
                textField.textAlignment = .right
                textField.font = UIFont.preferredFont(forTextStyle: .title3)
                textField.autocorrectionType = .no
                textField.autocapitalizationType = .none
                textField.placeholder = placeholder
            }
        }
        else {
            RowTextField(text: $text, isFocused: $isFocused, maxLength: 20) { textField in
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
