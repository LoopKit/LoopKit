//
//  UIAlertController.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 1/22/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

extension UIAlertController {
    /// Convenience method to initialize an alert controller to display an error
    ///
    /// - Parameters:
    ///   - error: The error to display
    ///   - title: The title of the alert. If nil, the error description will be used.
    ///   - helpAnchorHandler: An optional closure to be executed when a user taps to open the error's `helpAnchor`
    ///   - url: A URL created from the error's helpAnchor property
    public convenience init(with error: Error, title: String? = nil, helpAnchorHandler: ((_ url: URL) -> Void)? = nil) {
        var actions: [UIAlertAction] = []
        let errorTitle: String
        let message: String

        if let error = error as? LocalizedError {

            let sentenceFormat = LocalizedString("%@.", comment: "Appends a full-stop to a statement")
            let messageWithRecovery = [error.failureReason, error.recoverySuggestion].compactMap({ $0 }).map({
                String(format: sentenceFormat, $0)
            }).joined(separator: "\n")

            if messageWithRecovery.isEmpty {
                message = error.localizedDescription
            } else {
                message = messageWithRecovery
            }

            if let helpAnchor = error.helpAnchor, let url = URL(string: helpAnchor), let helpAnchorHandler = helpAnchorHandler {
                actions.append(UIAlertAction(
                    title: LocalizedString("More Info", comment: "Alert action title to open error help"),
                    style: .default,
                    handler: { (_) in helpAnchorHandler(url) }
                ))
            }

            errorTitle = (error.errorDescription ?? error.localizedDescription).localizedCapitalized

        } else {

            // See: https://forums.developer.apple.com/thread/17431
            // The compiler automatically emits the code necessary to translate between any ErrorType and NSError.
            let castedError = error as NSError
            errorTitle = error.localizedDescription.localizedCapitalized
            message = castedError.localizedRecoverySuggestion ?? String(describing: error)
        }

        self.init(title: title ?? errorTitle, message: message, preferredStyle: .alert)

        let action = UIAlertAction(
            title: LocalizedString("com.loudnate.LoopKit.errorAlertActionTitle", value: "OK", comment: "The title of the action used to dismiss an error alert"), style: .default)
        addAction(action)
        self.preferredAction = action

        for action in actions {
            addAction(action)
        }
    }
}
