//
//  RowTextField.swift
//  LoopKitUI
//
//  Created by Noah Brauner on 7/20/23.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI

/// A text field that supports custom input keyboards, moves the cursor to the end of the text, becomes the first responder when it's the focused row, and loses first responder when it's not
struct RowTextField<Row: Equatable>: UIViewRepresentable {
    @Binding var text: String
    @Binding var expandedRow: Row?
    let thisRow: Row
    var maxLength: Int? = nil
    var configuration = { (view: CustomInputTextField) in }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, expandedRow: $expandedRow, thisRow: thisRow, maxLength: maxLength)
    }

    func makeUIView(context: UIViewRepresentableContext<RowTextField>) -> CustomInputTextField {
        let textField = CustomInputTextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: CustomInputTextField, context: UIViewRepresentableContext<RowTextField>) {
        textField.text = text
        configuration(textField)
        DispatchQueue.main.async {
            if expandedRow == thisRow && !textField.isFirstResponder {
                textField.becomeFirstResponder()
            } else if expandedRow != thisRow && textField.isFirstResponder {
                textField.resignFirstResponder()
            }
        }
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        @Binding var expandedRow: Row?
        let thisRow: Row
        let maxLength: Int?
        
        init(text: Binding<String>, expandedRow: Binding<Row?>, thisRow: Row, maxLength: Int?) {
            _text = text
            _expandedRow = expandedRow
            self.thisRow = thisRow
            self.maxLength = maxLength
        }
        
        @objc fileprivate func textChanged(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async { [weak textField] in
                textField?.selectedTextRange = textField?.textRange(from: textField!.endOfDocument, to: textField!.endOfDocument)
            }
            withAnimation {
                expandedRow = thisRow
            }
        }
        
        func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
            if expandedRow == thisRow {
                expandedRow = nil
            }
            return true
        }
        
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            guard let maxLength = maxLength else {
                return true
            }
            let currentString: NSString = (textField.text ?? "") as NSString
            let newString: NSString = currentString.replacingCharacters(in: range, with: string) as NSString
            return newString.length <= maxLength
        }
    }
}

