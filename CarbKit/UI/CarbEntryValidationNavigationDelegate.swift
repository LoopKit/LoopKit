//
//  CarbEntryNavigationDelegate.swift
//  LoopKit
//
//  Created by Jaim Zuber on 2/7/17.
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import Foundation

class CarbEntryNavigationDelegate {
    
    func performSegue(withIdentifier identifier: String, sender: Any?, for viewController: UIViewController) {
        viewController.performSegue(withIdentifier: identifier, sender: sender)
    }
    
    func showAbsorptionTimeValidationWarning(for viewController: UIViewController) {
        viewController.presentAlertController(withTitle: NSLocalizedString("Warning", comment:"Title of the warning displayed after entering a carb absorption time greater than the max"), message: NSLocalizedString("That's a long time for absorption. Try a number below 999", comment:"Warning message body displayed after entering a carb absorption time greater than the max"))
    }
}
