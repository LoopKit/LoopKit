//
//  PumpManagerUI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import SwiftUI
import LoopKit

public struct PumpManagerDescriptor {
    public let identifier: String
    public let localizedTitle: String

    public init(identifier: String, localizedTitle: String) {
        self.identifier = identifier
        self.localizedTitle = localizedTitle
    }
}

public struct PumpManagerSetupSettings {
    public var maxBasalRateUnitsPerHour: Double
    public var maxBolusUnits: Double
    public var basalSchedule: BasalRateSchedule

    public init(maxBasalRateUnitsPerHour: Double, maxBolusUnits: Double, basalSchedule: BasalRateSchedule) {
        self.maxBasalRateUnitsPerHour = maxBasalRateUnitsPerHour
        self.maxBolusUnits = maxBolusUnits
        self.basalSchedule = basalSchedule
    }
}

public protocol PumpStatusIndicator {
    /// a message from the pump that needs to be brought to the user's attention in the status bar
    var pumpStatusHighlight: DeviceStatusHighlight? { get }

    /// the completed percent of the progress bar to display in the status bar
    var pumpLifecycleProgress: DeviceLifecycleProgress? { get }

    /// a badge from the pump that needs to be brought to the user's attention in the status bar
    var pumpStatusBadge: DeviceStatusBadge? { get }
}

public typealias PumpManagerViewController = (UIViewController & PumpManagerOnboarding & CompletionNotifying)

public protocol PumpManagerUI: DeviceManagerUI, PumpStatusIndicator, PumpManager {

    /// Create and onboard a new pump manager.
    ///
    /// - Parameters:
    ///     - settings: Settings used to configure the pump manager.
    ///     - bluetoothProvider: The provider of Bluetooth functionality.
    ///     - colorPalette: Color palette to use for any UI.
    ///     - allowedInsulinTypes: Types that the caller allows to be selected.
    /// - Returns: Either a conforming view controller to create and onboard the pump manager or a newly created and onboarded pump manager.
    static func setupViewController(initialSettings settings: PumpManagerSetupSettings, bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, allowedInsulinTypes: [InsulinType]) -> SetupUIResult<PumpManagerViewController, PumpManagerUI>

    /// Configure settings for an existing pump manager.
    ///
    /// - Parameters:
    ///     - bluetoothProvider: The provider of Bluetooth functionality.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: A view controller to configure an existing pump manager.
    func settingsViewController(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, allowedInsulinTypes: [InsulinType]) -> PumpManagerViewController

    // View for recovering from delivery uncertainty
    func deliveryUncertaintyRecoveryViewController(colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> (UIViewController & CompletionNotifying)

    // Returns a class that can provide HUD views
    func hudProvider(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette, allowedInsulinTypes: [InsulinType]) -> HUDProvider?

    // Instantiates HUD view (typically reservoir volume) from the raw state returned by hudViewRawState
    static func createHUDView(rawValue: HUDProvider.HUDViewRawState) -> BaseHUDView?
}

public protocol PumpManagerOnboardingDelegate: AnyObject {
    /// Informs the delegate that the specified pump manager was created.
    ///
    /// - Parameters:
    ///     - pumpManager: The pump manager created.
    func pumpManagerOnboarding(didCreatePumpManager pumpManager: PumpManagerUI)

    /// Informs the delegate that the specified pump manager was onboarded.
    ///
    /// - Parameters:
    ///     - pumpManager: The pump manager onboarded.
    func pumpManagerOnboarding(didOnboardPumpManager pumpManager: PumpManagerUI)

    /// Informs the delegate that the specified pump manager wishes to pause onboarding
    ///
    /// - Parameters:
    ///     - pumpManager: The pump manager onboarded.
    func pumpManagerOnboarding(didPauseOnboarding pumpManager: PumpManagerUI)
}

public protocol PumpManagerOnboarding {
    /// Delegate to notify about pump manager onboarding.
    var pumpManagerOnboardingDelegate: PumpManagerOnboardingDelegate? { get set }
}
