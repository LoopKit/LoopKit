//
//  PumpManagerUI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit

public enum HUDTapAction {
    case showViewController(_ viewController: UIViewController)
    case openAppURL(_ appURL: URL)
}

public protocol PumpManagerUI: PumpManager, DeliveryLimitSettingsTableViewControllerSyncSource, SingleValueScheduleTableViewControllerSyncSource {
    typealias PumpManagerHUDViewsRawState = [String: Any]
    
    static func setupViewController() -> (UIViewController & PumpManagerSetupViewController)

    func settingsViewController() -> UIViewController
    
    // An image representing the pump configuration
    var smallImage: UIImage? { get }
    
    // Views to be shown in Loop HUD. Implementor should create new instances each time this function is called. Loop will retain strong references
    // to them for as long as they are in the view hierarchy.  If references to these views are kept, they should be weak, to avoid retain cycles.
    func createHUDViews() -> [BaseHUDView]
    
    // Returns the action that should be taken when the view identified by identifier is tapped
    func didTapOnHudView(_ view: BaseHUDView) -> HUDTapAction?
    
    // The current, serializable state of the status views
    var hudViewsRawState: PumpManagerHUDViewsRawState { get }
    
    // Instantiates HUD views from the raw state returned by hudViewsRawState
    static func createHUDViews(rawValue: PumpManagerHUDViewsRawState) -> [BaseHUDView]
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
