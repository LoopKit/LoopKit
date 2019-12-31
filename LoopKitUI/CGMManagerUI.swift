//
//  CGMManagerUI.swift
//  LoopKitUI
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit
import HealthKit


public protocol CGMManagerUI: CGMManager {
    /// Provides a view controller for setting up and configuring the manager if needed.
    ///
    /// If this method returns nil, it's expected that `init?(rawState: [:])` creates a non-nil manager
    static func setupViewController() -> (UIViewController & CGMManagerSetupViewController & CompletionNotifying)?

    func settingsViewController(for glucoseUnit: HKUnit) -> (UIViewController & CompletionNotifying)

    var smallImage: UIImage? { get }
}


public protocol CGMManagerSetupViewController {
    var setupDelegate: CGMManagerSetupViewControllerDelegate? { get set }
}


public protocol CGMManagerSetupViewControllerDelegate: class {
    func cgmManagerSetupViewController(_ cgmManagerSetupViewController: CGMManagerSetupViewController, didSetUpCGMManager cgmManager: CGMManagerUI)
}
