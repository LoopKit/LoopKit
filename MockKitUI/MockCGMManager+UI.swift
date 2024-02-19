//
//  MockCGMManager+UI.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/23/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import SwiftUI
import HealthKit
import LoopKit
import LoopKitUI
import MockKit


extension MockCGMManager: CGMManagerUI {

    fileprivate var appName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
    }
    
    public static var onboardingImage: UIImage? { return UIImage(named: "CGM Simulator", in: Bundle(for: MockCGMManagerSettingsViewController.self), compatibleWith: nil) }

    public var smallImage: UIImage? { return UIImage(named: "CGM Simulator", in: Bundle(for: MockCGMManagerSettingsViewController.self), compatibleWith: nil) }

    public static func setupViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool, prefersToSkipUserInteraction: Bool) -> SetupUIResult<CGMManagerViewController, CGMManagerUI> {
        return .createdAndOnboarded(MockCGMManager())
    }

    public func settingsViewController(bluetoothProvider: BluetoothProvider, displayGlucosePreference: DisplayGlucosePreference, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> CGMManagerViewController {
        let settings = MockCGMManagerSettingsView(cgmManager: self, displayGlucosePreference: displayGlucosePreference, appName: appName, allowDebugFeatures: allowDebugFeatures)
        let hostingController = DismissibleHostingController(content: settings, isModalInPresentation: false, colorPalette: colorPalette)
        hostingController.navigationItem.backButtonDisplayMode = .generic
        let nav = CGMManagerSettingsNavigationViewController(rootViewController: hostingController)
        nav.navigationBar.prefersLargeTitles = true
        return nav
    }

    public var cgmStatusBadge: DeviceStatusBadge? {
        return self.mockSensorState.cgmStatusBadge
    }
    
    public var cgmStatusHighlight: DeviceStatusHighlight? {
        return self.mockSensorState.cgmStatusHighlight
    }

    public var cgmLifecycleProgress: DeviceLifecycleProgress? {
        return self.mockSensorState.cgmLifecycleProgress
    }
}
