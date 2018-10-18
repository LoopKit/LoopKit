//
//  PumpManagerUI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit

public enum HUDTapAction {
    case presentViewController(viewController: UIViewController)
    case openAppURL(appURL: URL)
}

public protocol PumpManagerUI: PumpManager, DeliveryLimitSettingsTableViewControllerSyncSource, SingleValueScheduleTableViewControllerSyncSource {
    typealias PumpManagerHUDViewsRawState = [String: Any]
    
    static func setupViewController() -> (UIViewController & PumpManagerSetupViewController)

    func settingsViewController() -> UIViewController
    
    func hudViews() -> [BaseHUDView]
    
    func hudTapAction(identifier: HUDViewIdentifier) -> HUDTapAction?

    // An image representing the pump configuration
    var smallImage: UIImage? { get }
    
    /// The current, serializable state of the status views
    var hudViewsRawState: PumpManagerHUDViewsRawState { get }
    
    static func instantiateHUDViews(rawValue: PumpManagerHUDViewsRawState) -> [BaseHUDView]
}


public protocol PumpManagerSetupViewController {
    var setupDelegate: PumpManagerSetupViewControllerDelegate? { get set }

    var maxBasalRateUnitsPerHour: Double? { get set }

    var maxBolusUnits: Double? { get set }

    var basalSchedule: BasalRateSchedule? { get set }
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
