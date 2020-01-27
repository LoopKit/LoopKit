//
//  CarbEntryNavigationDelegate.swift
//  LoopKit
//
//  Created by Jaim Zuber on 2/7/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation

public class CarbEntryNavigationDelegate {
    private lazy var validationTitle = LocalizedString("Warning", comment: "Title of an alert containing a validation warning")
    private lazy var dismissActionTitle = LocalizedString("com.loudnate.LoopKit.errorAlertActionTitle", value: "OK", comment: "The title of the action used to dismiss an error alert")

    public init() {}

    public func showAbsorptionTimeValidationWarning(for viewController: UIViewController, maxAbsorptionTime: TimeInterval) {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .full

        let message = String(
            format: LocalizedString("The maximum absorption time is %@", comment: "Alert body displayed absorption time greater than max (1: maximum absorption time)"),
            formatter.string(from: maxAbsorptionTime) ?? String(describing: maxAbsorptionTime))
        let alert = UIAlertController(title: validationTitle, message: message, preferredStyle: .alert)

        let action = UIAlertAction(title: dismissActionTitle, style: .default)
        alert.addAction(action)
        alert.preferredAction = action

        viewController.present(alert, animated: true)
    }

    public func showMaxQuantityValidationWarning(for viewController: UIViewController, maxQuantityGrams: Double) {
        let message = String(
            format: LocalizedString("The maximum allowed amount is %@ grams", comment: "Alert body displayed for quantity greater than max (1: maximum quantity in grams)"),
            NumberFormatter.localizedString(from: NSNumber(value: maxQuantityGrams), number: .none)
        )
        let alert = UIAlertController(title: validationTitle, message: message, preferredStyle: .alert)

        let action = UIAlertAction(title: dismissActionTitle, style: .default)
        alert.addAction(action)
        alert.preferredAction = action

        viewController.present(alert, animated: true)
    }
}
