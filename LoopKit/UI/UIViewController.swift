//
//  UIViewController.swift
//  CarbKit
//
//  Created by Nathan Racklyeft on 1/16/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


extension UIViewController {
    /**
     Convenience method to present an alert controller on the active view controller

     - parameter title:      The title of the alert
     - parameter message:    The message of the alert
     - parameter animated:   Whether to animate the alert
     - parameter completion: An optional closure to execute after the presentation finishes
     */
    public func presentAlertController(withTitle title: String?, message: String, animated: Bool = true, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        let action = UIAlertAction(
            title: NSLocalizedString("com.loudnate.LoopKit.errorAlertActionTitle", tableName: "LoopKit", value: "OK", comment: "The title of the action used to dismiss an error alert"),
            style: .default,
            handler: nil
        )

        alert.addAction(action)
        alert.preferredAction = action

        presentViewControllerOnActiveViewController(alert, animated: animated, completion: completion)
    }

    /**
     Convenience method to display an error object in an alert controller

     - parameter error:      The error to display
     - parameter animated:   Whether to animate the alert
     - parameter completion: An optional closure to execute after the presentation finishes
     */
    public func presentAlertController(with error: Error, animated: Bool = true, completion: (() -> Void)? = nil) {

        // See: https://forums.developer.apple.com/thread/17431
        // The compiler automatically emits the code necessary to translate between any ErrorType and NSError.
        let castedError = error as NSError

        presentAlertController(
            withTitle: error.localizedDescription,
            message: castedError.localizedRecoverySuggestion ?? String(describing: error),
            animated: animated,
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
    public func presentViewControllerOnActiveViewController(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)?) {
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
