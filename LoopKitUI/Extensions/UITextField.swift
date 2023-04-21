//
//  UITextField.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 9/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

extension UITextField {
    
    func selectAll() {
        dispatchPrecondition(condition: .onQueue(.main))
        self.selectedTextRange = self.textRange(from: self.beginningOfDocument, to: self.endOfDocument)
    }

    func moveCursorToEnd() {
        dispatchPrecondition(condition: .onQueue(.main))
        let newPosition = self.endOfDocument
        self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
    }
    
    func moveCursorToBeginning() {
        dispatchPrecondition(condition: .onQueue(.main))
        let newPosition = self.beginningOfDocument
        self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
    }
}
