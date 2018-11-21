//
//  MockPumpManagerSetupViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit


final class MockPumpManagerSetupViewController: UINavigationController, PumpManagerSetupViewController {

    static func instantiateFromStoryboard() -> MockPumpManagerSetupViewController {
        return UIStoryboard(name: "MockPumpManager", bundle: Bundle(for: MockPumpManagerSetupViewController.self)).instantiateInitialViewController() as! MockPumpManagerSetupViewController
    }

    var maxBasalRateUnitsPerHour: Double?

    var maxBolusUnits: Double?

    var basalSchedule: BasalRateSchedule?

    let pumpManager = MockPumpManager()

    weak var setupDelegate: PumpManagerSetupViewControllerDelegate?

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        navigationBar.shadowImage = UIImage()

        delegate = self
    }

    func completeSetup() {
        setupDelegate?.pumpManagerSetupViewController(self, didSetUpPumpManager: pumpManager)
    }
}

extension MockPumpManagerSetupViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        switch viewController {
        case let vc as MockPumpManagerSettingsSetupViewController:
            vc.pumpManager = pumpManager
        default:
            break
        }

        // Adjust the appearance for the main setup view controllers only
        if viewController is SetupTableViewController {
            navigationBar.isTranslucent = false
            navigationBar.shadowImage = UIImage()
        } else {
            navigationBar.isTranslucent = true
            navigationBar.shadowImage = nil
        }
    }
}
