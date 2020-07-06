//
//  MockCGMManager+UI.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 11/23/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import MockKit


extension MockCGMManager: CGMManagerUI {
    public static func setupViewController() -> (UIViewController & CGMManagerSetupViewController & CompletionNotifying)? {
        return nil
    }

    public func settingsViewController(for glucoseUnit: HKUnit) -> (UIViewController & CompletionNotifying) {
        let settings = MockCGMManagerSettingsViewController(cgmManager: self, glucoseUnit: glucoseUnit)
        let nav = SettingsNavigationViewController(rootViewController: settings)
        return nav
    }

    public var smallImage: UIImage? {
        return nil
    }
    
    public var cgmStatusHighlight: DeviceStatusHighlight? {
        return self.mockSensorState.cgmStatusHighlight
    }
    
    // TODO Placeholder. This functionality will come with LOOP-1293
    public var cgmLifecycleProgress: DeviceLifecycleProgress? {
        return self.mockSensorState.cgmLifecycleProgress
    }
}

extension MockCGMLifecycleProgress {
    var color: UIColor {
        return progressState.color
    }
}
