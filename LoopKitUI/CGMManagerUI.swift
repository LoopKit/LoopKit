//
//  CGMManagerUI.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public struct CGMManagerDescriptor {
    public let identifier: String
    public let localizedTitle: String

    public init(identifier: String, localizedTitle: String) {
        self.identifier = identifier
        self.localizedTitle = localizedTitle
    }
}

public protocol CGMStatusIndicator {
    /// a message from the cgm that needs to be brought to the user's attention in the status bar
    var cgmStatusHighlight: DeviceStatusHighlight? { get }

    /// the completed percent of the progress bar to display in the status bar
    var cgmLifecycleProgress: DeviceLifecycleProgress? { get }

    /// a badge from the cgm that needs to be brought to the user's attention in the status bar
    var cgmStatusBadge: DeviceStatusBadge? { get }

    /// gets the range category of a glucose sample using the CGM manager managed glucose thresholds
    func glucoseRangeCategory(for glucose: GlucoseSampleValue) -> GlucoseRangeCategory?
}

public protocol CGMManagerUI: CGMManager, DeviceManagerUI, DisplayGlucoseUnitObserver, CGMStatusIndicator {
    /// Create and onboard a new CGM manager.
    ///
    /// - Parameters:
    ///     - bluetoothProvider: The provider of Bluetooth functionality.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: Either a conforming view controller to create and onboard the CGM manager or a newly created and onboarded CGM manager.
    static func setupViewController(bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette) -> SetupUIResult<UIViewController & CGMManagerCreateNotifying & CGMManagerOnboardNotifying & CompletionNotifying, CGMManagerUI>

    /// Configure settings for an existing CGM manager.
    ///
    /// - Parameters:
    ///     - displayGlucoseUnitObservable: The glucose units to use for display.
    ///     - bluetoothProvider: The provider of Bluetooth functionality.
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: A view controller to configure an existing CGM manager.
    func settingsViewController(for displayGlucoseUnitObservable: DisplayGlucoseUnitObservable, bluetoothProvider: BluetoothProvider, colorPalette: LoopUIColorPalette) -> (UIViewController & CGMManagerOnboardNotifying & CompletionNotifying)
}

extension CGMManagerUI {
    public func glucoseRangeCategory(for glucose: GlucoseSampleValue) -> GlucoseRangeCategory? {
        return nil
    }

    /// When conformance to the DisplayGlucoseUnitObserver is desired, use this function to be notified when the user display glucose unit changes
    public func displayGlucoseUnitDidChange(to displayGlucoseUnit: HKUnit) {
        // optional
    }
}

public protocol CGMManagerCreateDelegate: AnyObject {
    /// Informs the delegate that the specified cgm manager was created.
    ///
    /// - Parameters:
    ///     - cgmManager: The cgm manager created.
    func cgmManagerCreateNotifying(didCreateCGMManager cgmManager: CGMManagerUI)
}

public protocol CGMManagerCreateNotifying {
    /// Delegate to notify about cgm manager creation.
    var cgmManagerCreateDelegate: CGMManagerCreateDelegate? { get set }
}

public protocol CGMManagerOnboardDelegate: AnyObject {
    /// Informs the delegate that the specified cgm manager was onboarded.
    ///
    /// - Parameters:
    ///     - cgmManager: The cgm manager onboarded.
    func cgmManagerOnboardNotifying(didOnboardCGMManager cgmManager: CGMManagerUI)
}

public protocol CGMManagerOnboardNotifying {
    /// Delegate to notify about cgm manager onboarding.
    var cgmManagerOnboardDelegate: CGMManagerOnboardDelegate? { get set }
}
