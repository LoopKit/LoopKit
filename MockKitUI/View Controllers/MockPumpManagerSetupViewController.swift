//
//  MockPumpManagerSetupViewController.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/20/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit
import LoopKitUI
import MockKit


final class MockPumpManagerSetupViewController: UINavigationController, PumpManagerOnboarding, CompletionNotifying {

    static func instantiateFromStoryboard() -> MockPumpManagerSetupViewController {
        return UIStoryboard(name: "MockPumpManager", bundle: Bundle(for: MockPumpManagerSetupViewController.self)).instantiateInitialViewController() as! MockPumpManagerSetupViewController
    }

    var maxBasalRateUnitsPerHour: Double?

    var maxBolusUnits: Double?

    var basalSchedule: BasalRateSchedule?

    let pumpManager = MockPumpManager()

    public weak var pumpManagerOnboardingDelegate: PumpManagerOnboardingDelegate?

    public weak var completionDelegate: CompletionDelegate?

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        
        navigationBar.shadowImage = UIImage()

        delegate = self
    }

    func completeSetup() {
        pumpManagerOnboardingDelegate?.pumpManagerOnboarding(didCreatePumpManager: pumpManager)

        let settings = PumpManagerSetupSettings(maxBasalRateUnitsPerHour: maxBasalRateUnitsPerHour,
                                                maxBolusUnits: maxBolusUnits,
                                                basalSchedule: basalSchedule)
        pumpManagerOnboardingDelegate?.pumpManagerOnboarding(didOnboardPumpManager: pumpManager, withFinalSettings: settings)
        
        completionDelegate?.completionNotifyingDidComplete(self)
    }

    public func finishedSettingsDisplay() {
        completionDelegate?.completionNotifyingDidComplete(self)
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
        if let setupViewController = viewController as? SetupTableViewController {
            setupViewController.delegate = self
            navigationBar.isTranslucent = false
            navigationBar.shadowImage = UIImage()
        } else {
            navigationBar.isTranslucent = true
            navigationBar.shadowImage = nil
        }
    }
}

extension MockPumpManagerSetupViewController: SetupTableViewControllerDelegate {
    public func setupTableViewControllerCancelButtonPressed(_ viewController: SetupTableViewController) {
        completionDelegate?.completionNotifyingDidComplete(self)
    }
}
