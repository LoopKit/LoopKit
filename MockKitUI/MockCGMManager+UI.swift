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
    public static func setupViewController() -> (UIViewController & CGMManagerSetupViewController)? {
        return nil
    }

    public func settingsViewController(for glucoseUnit: HKUnit) -> UIViewController {
        return MockCGMManagerSettingsViewController(cgmManager: self, glucoseUnit: glucoseUnit)
    }

    public var smallImage: UIImage? {
        return nil
    }
}
