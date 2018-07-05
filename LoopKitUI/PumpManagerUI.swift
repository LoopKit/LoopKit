//
//  PumpManagerUI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit


public protocol PumpManagerUI: PumpManager, DeliveryLimitSettingsTableViewControllerSyncSource, SingleValueScheduleTableViewControllerSyncSource {
    static func setupViewController() -> (UIViewController & PumpManagerSetupViewController)

    func settingsViewController() -> UIViewController

    // An image representing the pump configuration
    var smallImage: UIImage? { get }
}


public protocol PumpManagerSetupViewController {
    var setupDelegate: PumpManagerSetupViewControllerDelegate? { get set }

    var maxBasalRateUnitsPerHour: Double? { get }

    var maxBolusUnits: Double? { get }

    var basalSchedule: BasalRateSchedule? { get }
}


public protocol PumpManagerSetupViewControllerDelegate: class {
    func pumpManagerSetupViewController(_ pumpManagerSetupViewController: PumpManagerSetupViewController, didSetUpPumpManager pumpManager: PumpManagerUI)

    func pumpManagerSetupViewControllerDidCancel(_ pumpManagerSetupViewController: PumpManagerSetupViewController)
}


public extension PumpManagerSetupViewController {
    func cancelSetup() {
        setupDelegate?.pumpManagerSetupViewControllerDidCancel(self)
    }
}
