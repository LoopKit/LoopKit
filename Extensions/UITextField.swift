//
//  UITextField.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 9/17/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import UIKit

extension UITextField {
    
    func selectAll(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.selectedTextRange = self.textRange(from: self.beginningOfDocument, to: self.endOfDocument)
            completion?()
        }
    }

    func moveCursorToEnd(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let newPosition = self.endOfDocument
            self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
            completion?()
        }
    }
    
    func moveCursorToBeginning(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let newPosition = self.beginningOfDocument
            self.selectedTextRange = self.textRange(from: newPosition, to: newPosition)
            completion?()
        }
    }
}
