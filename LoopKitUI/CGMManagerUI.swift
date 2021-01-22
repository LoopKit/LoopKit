//
//  CGMManagerUI.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import SwiftUI
import LoopKit

public protocol CGMManagerUI: CGMManager, DeviceManagerUI, PreferredGlucoseUnitObserver {
    /// Provides a view controller for setting up and configuring the manager if needed.
    ///
    /// If this method returns nil, it's expected that `init?(rawState: [:])` creates a non-nil manager
    static func setupViewController(glucoseTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CGMManagerSetupViewController & CompletionNotifying)?

    func settingsViewController(for glucoseUnit: HKUnit, glucoseTintColor: Color, guidanceColors: GuidanceColors) -> (UIViewController & CompletionNotifying & PreferredGlucoseUnitObserver)

    /// a message from the cgm that needs to be brought to the user's attention in the status bar
    var cgmStatusHighlight: DeviceStatusHighlight? { get }
    
    /// the completed percent of the progress bar to display in the status bar
    var cgmLifecycleProgress: DeviceLifecycleProgress? { get }
    
    /// gets the range category of a glucose sample using the CGM manager managed glucose thresholds
    func glucoseRangeCategory(for glucose: GlucoseSampleValue) -> GlucoseRangeCategory?
}

extension CGMManagerUI {
    public func glucoseRangeCategory(for glucose: GlucoseSampleValue) -> GlucoseRangeCategory? {
        return nil
    }

    /// When conformance to the PreferredGlucoseUnitObserver is desired, use this function to be notified when the user preferred glucose unit changes
    public func preferredGlucoseUnitDidChange(to preferredGlucoseUnit: HKUnit) {
        // optional
    }
}

public protocol CGMManagerSetupViewController {
    var setupDelegate: CGMManagerSetupViewControllerDelegate? { get set }
}

public protocol CGMManagerSetupViewControllerDelegate: class {
    func cgmManagerSetupViewController(_ cgmManagerSetupViewController: CGMManagerSetupViewController, didSetUpCGMManager cgmManager: CGMManagerUI)
}
