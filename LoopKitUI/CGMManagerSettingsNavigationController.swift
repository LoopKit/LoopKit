//
//  CGMManagerSettingsNavigationController.swift
//  MockKitUI
//
//  Created by Nathaniel Hamming on 2021-01-13.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit

final public class CGMManagerSettingsNavigationController: SettingsNavigationViewController, PreferredGlucoseUnitObserver {

    private var rootViewController: UIViewController & PreferredGlucoseUnitObserver

    public init(rootViewController: UIViewController & PreferredGlucoseUnitObserver) {
        self.rootViewController = rootViewController
        super.init(rootViewController: rootViewController)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func preferredGlucoseUnitDidChange(to preferredGlucoseUnit: HKUnit) {
        rootViewController.preferredGlucoseUnitDidChange(to: preferredGlucoseUnit)
    }
}
