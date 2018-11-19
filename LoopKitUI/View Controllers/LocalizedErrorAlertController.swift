//
//  LocalizedErrorAlertController.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 11/16/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit

public class LocalizedErrorAlertController: UIAlertController {
    public convenience init(title: String, error: Error) {
        
        let message: String
        
        if let localizedError = error as? LocalizedError {
            let sentenceFormat = LocalizedString("%@.", comment: "Appends a full-stop to a statement")
            message = [localizedError.failureReason, localizedError.recoverySuggestion].compactMap({ $0 }).map({
                String(format: sentenceFormat, $0)
            }).joined(separator: "\n")
        } else {
            message = String(describing: error)
        }
        
        self.init(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        addAction(UIAlertAction(
            title: LocalizedString("OK", comment: "Button title to acknowledge error"),
            style: .default,
            handler: nil
        ))
    }
}
