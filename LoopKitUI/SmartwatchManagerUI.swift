//
//  SmartwatchManagerUI.swift
//  LoopKitUI
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import UIKit
import LoopKit

public struct SmartwatchManagerDescriptor {
    public let identifier: String
    public let localizedTitle: String
    /// The watches the plugin supports, or other details shown under the title in the picker
    public let subtitle: String?
    public let manufacturer: String?
    public let image: UIImage?

    public init(
        identifier: String,
        localizedTitle: String,
        subtitle: String? = nil,
        manufacturer: String?,
        image: UIImage?
    ) {
        self.identifier = identifier
        self.localizedTitle = localizedTitle
        self.subtitle = subtitle
        self.manufacturer = manufacturer
        self.image = image
    }
}

public typealias SmartwatchManagerViewController = (UIViewController & SmartwatchManagerOnboarding & CompletionNotifying)

/// The display unit reaches the plugin in each `SmartwatchStatusSnapshot`, so
/// the UI protocol doesn't observe unit changes separately.
public protocol SmartwatchManagerUI: SmartwatchManager, DeviceManagerUI {
    /// Create and onboard a new watch manager.
    ///
    /// - Parameters:
    ///     - bluetoothProvider: The provider of Bluetooth functionality.
    ///     - displayGlucosePreference: The glucose units to use for display.
    ///     - colorPalette: Color palette to use for any UI.
    ///     - allowDebugFeatures: Whether the host is a debug build that may show test tools.
    /// - Returns: Either a conforming view controller to create and onboard the watch manager or a newly created and onboarded watch manager.
    @MainActor
    static func setupViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> SetupUIResult<SmartwatchManagerViewController, SmartwatchManagerUI>

    /// Configure settings for an existing watch manager.
    ///
    /// - Parameters:
    ///     - bluetoothProvider: The provider of Bluetooth functionality.
    ///     - displayGlucosePreference: The glucose units to use for display.
    ///     - colorPalette: Color palette to use for any UI.
    ///     - allowDebugFeatures: Whether the host is a debug build that may show test tools.
    /// - Returns: A view controller to configure an existing watch manager.
    @MainActor
    func settingsViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> SmartwatchManagerViewController
}

@MainActor
public protocol SmartwatchManagerOnboardingDelegate: AnyObject {
    /// Informs the delegate that the specified watch manager was created.
    ///
    /// - Parameters:
    ///     - smartwatchManager: The watch manager created.
    func smartwatchManagerOnboarding(didCreateSmartwatchManager smartwatchManager: SmartwatchManagerUI)

    /// Informs the delegate that the specified watch manager was onboarded.
    ///
    /// - Parameters:
    ///     - smartwatchManager: The watch manager onboarded.
    func smartwatchManagerOnboarding(didOnboardSmartwatchManager smartwatchManager: SmartwatchManagerUI)
}

@MainActor
public protocol SmartwatchManagerOnboarding {
    /// Delegate to notify about watch manager onboarding.
    var smartwatchManagerOnboardingDelegate: SmartwatchManagerOnboardingDelegate? { get set }
}
