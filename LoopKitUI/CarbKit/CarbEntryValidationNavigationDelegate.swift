//
//  CarbEntryNavigationDelegate.swift
//  LoopKit
//
//  Created by Jaim Zuber on 2/7/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation

class CarbEntryNavigationDelegate {
    lazy var validationTitle = LocalizedString("Warning", comment: "Title of an alert containing a validation warning")

    func showAbsorptionTimeValidationWarning(for viewController: UIViewController, maxAbsorptionTime: TimeInterval) {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .full

        viewController.presentAlertController(
            withTitle: validationTitle,
            message: String(
                format: LocalizedString("The maximum absorption time is %@", comment: "Alert body displayed absorption time greater than max (1: maximum absorption time)"),
                formatter.string(from: maxAbsorptionTime) ?? String(describing: maxAbsorptionTime)
            )
        )
    }

    func showMaxQuantityValidationWarning(for viewController: UIViewController, maxQuantityGrams: Double) {
        viewController.presentAlertController(
            withTitle: validationTitle,
            message: String(
                format: LocalizedString("The maximum allowed amount is %@ grams", comment: "Alert body displayed for quantity greater than max (1: maximum quantity in grams)"),
                NumberFormatter.localizedString(from: NSNumber(value: maxQuantityGrams), number: .none)
            )
        )
    }
}
