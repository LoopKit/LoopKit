//
//  PumpManagerUI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit

public protocol PumpManagerUI: PumpManager, DeliveryLimitSettingsTableViewControllerSyncSource, SingleValueScheduleTableViewControllerSyncSource {
    
    static func setupViewController() -> (UIViewController & PumpManagerSetupViewController & CompletionNotifying)

    func settingsViewController() -> (UIViewController & CompletionNotifying)
    
    // An image representing the pump configuration
    var smallImage: UIImage? { get }
    
    // Returns a class that can provide HUD views
    func hudProvider() -> HUDProvider?
    
    // Instantiates HUD views from the raw state returned by hudViewsRawState
    static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView]
}


public protocol PumpManagerSetupViewController {
    var setupDelegate: PumpManagerSetupViewControllerDelegate? { get set }

    var maxBasalRateUnitsPerHour: Double? { get set }

    var maxBolusUnits: Double? { get set }

    var basalSchedule: BasalRateSchedule? { get set }
}


public protocol PumpManagerSetupViewControllerDelegate: class {
    func pumpManagerSetupViewController(_ pumpManagerSetupViewController: PumpManagerSetupViewController, didSetUpPumpManager pumpManager: PumpManagerUI)
}
