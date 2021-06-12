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

    public static var onboardingImage: UIImage? { return UIImage(named: "CGM Simulator", in: Bundle(for: MockCGMManagerSettingsViewController.self), compatibleWith: nil) }

    public var smallImage: UIImage? { return UIImage(named: "CGM Simulator", in: Bundle(for: MockCGMManagerSettingsViewController.self), compatibleWith: nil) }

    public static func setupViewController(bluetoothProvider: BluetoothProvider, displayGlucoseUnitObservable: DisplayGlucoseUnitObservable, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> SetupUIResult<CGMManagerViewController, CGMManagerUI> {
        return .createdAndOnboarded(MockCGMManager())
    }

    public func settingsViewController(bluetoothProvider: BluetoothProvider, displayGlucoseUnitObservable: DisplayGlucoseUnitObservable, colorPalette: LoopUIColorPalette, allowDebugFeatures: Bool) -> CGMManagerViewController {
        let settings = MockCGMManagerSettingsViewController(cgmManager: self, displayGlucoseUnitObservable: displayGlucoseUnitObservable)
        let nav = CGMManagerSettingsNavigationViewController(rootViewController: settings)
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
