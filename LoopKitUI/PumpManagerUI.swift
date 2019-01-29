//
//  PumpManagerUI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit

public protocol CompletionDelegate: class {
    func didComplete(viewController: UIViewController)
}

public protocol CompletionNotifying {
    var completionDelegate: CompletionDelegate? { set get }
}

public enum HUDTapAction {
    case presentViewController(UIViewController & CompletionNotifying)
    case openAppURL(URL)
}

public protocol HUDProviderDelegate: class {
    func hudProvider(_ provider: HUDProvider, didAddViews views: [BaseHUDView])
    func hudProvider(_ provider: HUDProvider, didRemoveViews views: [BaseHUDView])
    func hudProvider(_ provider: HUDProvider, didReplaceViews views: [BaseHUDView])
}

public protocol HUDProvider {
    var managerIdentifier: String { get }
    
    var delegate: HUDProviderDelegate? { set get }
    
    typealias HUDViewsRawState = [String: Any]

    // Creates the initial views to be shown in Loop HUD.
    func createHUDViews() -> [BaseHUDView]
    
    // Returns the action that should be taken when the view is tapped
    func didTapOnHUDView(_ view: BaseHUDView) -> HUDTapAction?
    
    // The current, serializable state of the HUD views
    var hudViewsRawState: HUDViewsRawState { get }
    
    func hudDidAppear()
}

public protocol PumpManagerUI: PumpManager, DeliveryLimitSettingsTableViewControllerSyncSource, SingleValueScheduleTableViewControllerSyncSource {
    
    static func setupViewController() -> (UIViewController & PumpManagerSetupViewController)

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

    func pumpManagerSetupViewControllerDidCancel(_ pumpManagerSetupViewController: PumpManagerSetupViewController)
}
