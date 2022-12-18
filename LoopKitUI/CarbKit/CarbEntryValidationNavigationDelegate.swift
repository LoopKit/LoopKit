//
//  CarbEntryNavigationDelegate.swift
//  LoopKit
//
//  Created by Jaim Zuber on 2/7/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation

public class CarbEntryNavigationDelegate {
    private lazy var dismissActionTitle = LocalizedString("com.loudnate.LoopKit.errorAlertActionTitle", value: "OK", comment: "The title of the action used to dismiss an error alert")

    public init() {}

    public func showAbsorptionTimeValidationWarning(for viewController: UIViewController, maxAbsorptionTime: TimeInterval) {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .full

        let message = String(
            format: LocalizedString("The maximum absorption time is %@", comment: "Alert body displayed absorption time greater than max (1: maximum absorption time)"),
            formatter.string(from: maxAbsorptionTime) ?? String(describing: maxAbsorptionTime))
        let validationTitle = LocalizedString("Maximum Duration Exceeded", comment: "Alert title when maximum duration exceeded.")
        let alert = UIAlertController(title: validationTitle, message: message, preferredStyle: .alert)

        let action = UIAlertAction(title: dismissActionTitle, style: .default)
        alert.addAction(action)
        alert.preferredAction = action

        viewController.present(alert, animated: true)
    }

    public func showWarningQuantityValidationWarning(for viewController: UIViewController, enteredGrams: Double, didConfirm: @escaping () -> Void) {
        let warningTitle = LocalizedString("Large Meal Entered", comment: "Title of the warning shown when a large meal was entered")

        let message = String(
            format: LocalizedString("Did you intend to enter %1$@ grams as the amount of carbohydrates for this meal?", comment: "Alert body when entered carbohydrates is greater than threshold (1: entered quantity in grams)"),
            NumberFormatter.localizedString(from: NSNumber(value: enteredGrams), number: .none)
                )
        let alert = UIAlertController(title: warningTitle, message: message, preferredStyle: .alert)

        let editButtonText = LocalizedString("No, edit amount", comment: "The title of the action used when rejecting the the amount of carbohydrates entered.")
        let editAction = UIAlertAction(title: editButtonText, style: .default)
        alert.addAction(editAction)

        let confirmButtonText = LocalizedString("Yes", comment: "The title of the action used when confirming entered amount of carbohydrates.")
        let confirm = UIAlertAction(title: confirmButtonText, style: .default) {_ in
            didConfirm();
        }
        alert.addAction(confirm)
        alert.preferredAction = confirm

        viewController.present(alert, animated: true)
    }

    public func showMaxQuantityValidationWarning(for viewController: UIViewController, maxQuantityGrams: Double) {
        let errorTitle = LocalizedString("Input Maximum Exceeded", comment: "Title of the alert when carb input maximum was exceeded.")
        let message = String(
            format: LocalizedString("The maximum allowed amount is %@ grams.", comment: "Alert body displayed for quantity greater than max (1: maximum quantity in grams)"),
            NumberFormatter.localizedString(from: NSNumber(value: maxQuantityGrams), number: .none)
        )
        let alert = UIAlertController(title: errorTitle, message: message, preferredStyle: .alert)

        let action = UIAlertAction(title: dismissActionTitle, style: .default)
        alert.addAction(action)
        alert.preferredAction = action

        viewController.present(alert, animated: true)
    }
}
