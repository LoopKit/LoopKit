//
//  UIViewController.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/16/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


extension UIViewController {
    /// Convenience method to present an alert controller on the active view controller
    ///
    /// - Parameters:
    ///   - title: The title of the alert
    ///   - message: The message of the alert
    ///   - animated: Whether to animate the alert
    ///   - actions: Additional, non-preferred actions to display to the user
    ///   - completion: An optional closure to execute after the presentation finishes
    public func presentAlertController(withTitle title: String?, message: String, animated: Bool = true, actions: [UIAlertAction] = [], completion: (() -> Void)? = nil) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        let action = UIAlertAction(
            title: LocalizedString("com.loudnate.LoopKit.errorAlertActionTitle", value: "OK", comment: "The title of the action used to dismiss an error alert"),
            style: .default,
            handler: nil
        )

        alert.addAction(action)
        alert.preferredAction = action

        for action in actions {
            alert.addAction(action)
        }

        presentViewControllerOnActiveViewController(alert, animated: animated, completion: completion)
    }

    /// Convenience method to display an error object in an alert controller
    ///
    /// - Parameters:
    ///   - error: The error to display
    ///   - animated: Whether to animate the alert
    ///   - completion: An optional closure to execute after the presentation finishes
    public func presentAlertController(with error: Error, animated: Bool = true, completion: (() -> Void)? = nil) {
        if let error = error as? LocalizedError {
            presentAlertController(configuredWith: error, animated: animated, completion: completion)
            return
        }

        // See: https://forums.developer.apple.com/thread/17431
        // The compiler automatically emits the code necessary to translate between any ErrorType and NSError.
        let castedError = error as NSError

        presentAlertController(
            withTitle: error.localizedDescription.localizedCapitalized,
            message: castedError.localizedRecoverySuggestion ?? String(describing: error),
            animated: animated,
            completion: completion
        )
    }

    /// Convenience method to display a localized error object in an alert controller
    ///
    /// - Parameters:
    ///   - error: The error to display
    ///   - animated: Whether to animate the alert
    ///   - completion: An optional closure to execute after the presentation finishes
    func presentAlertController(configuredWith error: LocalizedError, animated: Bool = true, completion: (() -> Void)? = nil) {
        let message = [error.failureReason, error.recoverySuggestion].compactMap({ $0 }).joined(separator: ".\n")

        var actions: [UIAlertAction] = []

        if let helpAnchor = error.helpAnchor, let url = URL(string: helpAnchor) {
            actions.append(UIAlertAction(
                title: LocalizedString("More Info", comment: "Alert action title to open error help"),
                style: .default,
                handler: { (action) in
                    UIApplication.shared.open(url)
                }
            ))
        }

        presentAlertController(
            withTitle: (error.errorDescription ?? error.localizedDescription).localizedCapitalized,
            message: message.isEmpty ? String(describing: error) : message,
            animated: animated,
            actions: actions,
            completion: completion
        )
    }

    /**
     Convenience method to present a view controller on the active view controller.
     
     If the receiver is not in a window, or already has a presented view controller, this method will
     attempt to find the most appropriate view controller for presenting.

     - parameter viewControllerToPresent: The view controller to display over the view controller’s content
     - parameter animated:                Whether to animate the presentation
     - parameter completion:              An optional closure to execute after the presentation finishes
     */
    func presentViewControllerOnActiveViewController(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)?) {
        var presentingViewController: UIViewController? = self

        if presentingViewController?.view.window == nil {
            presentingViewController = UIApplication.shared.delegate?.window??.rootViewController
        }

        while presentingViewController?.presentedViewController != nil {
            presentingViewController = presentingViewController?.presentedViewController
        }

        presentingViewController?.present(viewControllerToPresent, animated: animated, completion: completion)
    }
}
