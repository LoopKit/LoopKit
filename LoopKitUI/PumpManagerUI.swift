//
//  PumpManagerUI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import SwiftUI
import LoopKit

public protocol PumpManagerUI: DeviceManagerUI, PumpManager, DeliveryLimitSettingsTableViewControllerSyncSource, BasalScheduleTableViewControllerSyncSource {
    
    // View for initial setup of device.
    static func setupViewController(insulinTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & PumpManagerSetupViewController & CompletionNotifying)

    // View for managing device after initial setup
    func settingsViewController(insulinTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CompletionNotifying)

    // View for recovering from delivery uncertainty
    func deliveryUncertaintyRecoveryViewController(insulinTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CompletionNotifying)

    // Returns a class that can provide HUD views
    func hudProvider(insulinTintColor: Color, guidanceColors: GuidanceColors) -> HUDProvider?
    
    // Instantiates HUD view (typically reservoir volume) from the raw state returned by hudViewRawState
    static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> LevelHUDView?
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
