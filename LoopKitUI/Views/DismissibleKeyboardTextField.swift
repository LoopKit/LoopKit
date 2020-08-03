//
//  DismissibleKeyboardTextField.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI


public struct DismissibleKeyboardTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: UIFont
    var textColor: UIColor
    var textAlignment: NSTextAlignment
    var keyboardType: UIKeyboardType
    var autocapitalizationType: UITextAutocapitalizationType
    var autocorrectionType: UITextAutocorrectionType

    public init(
        text: Binding<String>,
        placeholder: String,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        textAlignment: NSTextAlignment = .natural,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        autocorrectionType: UITextAutocorrectionType = .default
    ) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.keyboardType = keyboardType
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
    }

    public func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.font = font
        textField.textColor = textColor
        textField.textAlignment = textAlignment
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = autocorrectionType
        textField.inputAccessoryView = makeDoneToolbar(for: textField)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        return textField
    }

    private func makeDoneToolbar(for textField: UITextField) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: textField, action: #selector(UITextField.resignFirstResponder))
        toolbar.items = [flexibleSpace, doneButton]
        toolbar.sizeToFit()
        return toolbar
    }

    public func updateUIView(_ textField: UITextField, context: Context) {
        textField.text = text
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public final class Coordinator {
        var parent: DismissibleKeyboardTextField

        init(_ parent: DismissibleKeyboardTextField) {
            self.parent = parent
        }

        @objc fileprivate func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}
