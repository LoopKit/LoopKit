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
    var shouldBecomeFirstResponder: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        textAlignment: NSTextAlignment = .natural,
        keyboardType: UIKeyboardType = .default,
        autocapitalizationType: UITextAutocapitalizationType = .sentences,
        autocorrectionType: UITextAutocorrectionType = .default,
        shouldBecomeFirstResponder: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.font = font
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.keyboardType = keyboardType
        self.autocapitalizationType = autocapitalizationType
        self.autocorrectionType = autocorrectionType
        self.shouldBecomeFirstResponder = shouldBecomeFirstResponder
    }

    public func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.inputAccessoryView = makeDoneToolbar(for: textField)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingDidBegin), for: .editingDidBegin)
        return textField
    }

    private func makeDoneToolbar(for textField: UITextField) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: textField, action: #selector(UITextField.resignFirstResponder))
        doneButton.tintColor = textColor
        toolbar.items = [flexibleSpace, doneButton]
        toolbar.sizeToFit()
        return toolbar
    }

    public func updateUIView(_ textField: UITextField, context: Context) {
        textField.text = text
        textField.placeholder = placeholder
        textField.font = font
        textField.textColor = textColor
        textField.textAlignment = textAlignment
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = autocorrectionType

        if shouldBecomeFirstResponder && !context.coordinator.didBecomeFirstResponder {
            textField.becomeFirstResponder()
            context.coordinator.didBecomeFirstResponder = true
        } else if !shouldBecomeFirstResponder && context.coordinator.didBecomeFirstResponder {
            context.coordinator.didBecomeFirstResponder = false
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public final class Coordinator {
        var parent: DismissibleKeyboardTextField

        // Track in the coordinator to ensure the text field only becomes first responder once,
        // rather than on every state change.
        var didBecomeFirstResponder = false

        init(_ parent: DismissibleKeyboardTextField) {
            self.parent = parent
        }

        @objc fileprivate func textChanged(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
        
        @objc fileprivate func editingDidBegin(_ textField: UITextField) {
            textField.moveCursorToEnd()
        }
    }
}

fileprivate extension UITextField {
    
    func moveCursorToEnd() {
        DispatchQueue.main.async {
            let newPosition = self.endOfDocument
            self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
        }
    }
    
    func moveCursorToBeginning() {
        DispatchQueue.main.async {
            let newPosition = self.beginningOfDocument
            self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
        }
    }
}
