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


final class MockPumpManagerSetupViewController: UINavigationController, PumpManagerCreateNotifying, PumpManagerOnboardNotifying, CompletionNotifying {

    static func instantiateFromStoryboard() -> MockPumpManagerSetupViewController {
        return UIStoryboard(name: "MockPumpManager", bundle: Bundle(for: MockPumpManagerSetupViewController.self)).instantiateInitialViewController() as! MockPumpManagerSetupViewController
    }

    var maxBasalRateUnitsPerHour: Double?

    var maxBolusUnits: Double?

    var basalSchedule: BasalRateSchedule?

    let pumpManager = MockPumpManager()

    public weak var pumpManagerCreateDelegate: PumpManagerCreateDelegate?

    public weak var pumpManagerOnboardDelegate: PumpManagerOnboardDelegate?

    public weak var completionDelegate: CompletionDelegate?

    override public func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } else {
            view.backgroundColor = .white
        }
        
        navigationBar.shadowImage = UIImage()

        delegate = self
    }

    func completeSetup() {
        pumpManagerCreateDelegate?.pumpManagerCreateNotifying(didCreatePumpManager: pumpManager)

        let settings = PumpManagerSetupSettings(maxBasalRateUnitsPerHour: maxBasalRateUnitsPerHour,
                                           maxBolusUnits: maxBolusUnits,
                                           basalSchedule: basalSchedule)
        pumpManagerOnboardDelegate?.pumpManagerOnboardNotifying(didOnboardPumpManager: pumpManager, withFinalSettings: settings)
        
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
