//
//  PumpManagerUI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit

public enum HUDTapAction {
    case showViewController(UIViewController)
    case presentViewController(UIViewController)
    case openAppURL(URL)
}

public protocol HUDProviderDelegate: class {
    func hudProvider(_ provider: HUDProvider, didAddHudViews views: [BaseHUDView])
    func hudProvider(_ provider: HUDProvider, didRemoveHudViews views: [BaseHUDView])
}

public protocol HUDProvider {
    var managerIdentifier: String { get }
    
    var delegate: HUDProviderDelegate? { set get }
    
    typealias HUDViewsRawState = [String: Any]

    // Creates the initial views to be shown in Loop HUD.
    func createHUDViews() -> [BaseHUDView]
    
    // Returns the action that should be taken when the view is tapped
    func didTapOnHudView(_ view: BaseHUDView) -> HUDTapAction?
    
    // The current, serializable state of the HUD views
    var hudViewsRawState: HUDViewsRawState { get }
    
    func hudDidAppear()
}

public protocol PumpManagerUI: PumpManager, DeliveryLimitSettingsTableViewControllerSyncSource, SingleValueScheduleTableViewControllerSyncSource {
    
    static func setupViewController() -> (UIViewController & PumpManagerSetupViewController)

    func settingsViewController() -> UIViewController
    
    // An image representing the pump configuration
    var smallImage: UIImage? { get }
    
    // Returns a class that can provide HUD views
    func hudProvider() -> HUDProvider?
    
    // Instantiates HUD views from the raw state returned by hudViewsRawState
    static func createHUDViews(rawValue: HUDProvider.HUDViewsRawState) -> [BaseHUDView]
}


public protocol PumpManagerSetupViewController: SetupNavigationController {
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
