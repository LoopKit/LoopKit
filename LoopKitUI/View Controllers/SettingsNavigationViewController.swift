//
//  SettingsNavigationViewController.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 1/29/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit

open class SettingsNavigationViewController: UINavigationController, CompletionNotifying {

    open weak var completionDelegate: CompletionDelegate?

    open func notifyComplete() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }

}

open class CGMManagerSettingsNavigationViewController: SettingsNavigationViewController, CGMManagerOnboardNotifying, PreferredGlucoseUnitObserver {

    open weak var cgmManagerOnboardDelegate: CGMManagerOnboardDelegate?

    private var rootViewController: UIViewController & PreferredGlucoseUnitObserver

    public init(rootViewController: UIViewController & PreferredGlucoseUnitObserver) {
        self.rootViewController = rootViewController
        super.init(rootViewController: rootViewController)
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func notifySetup(cgmManager: CGMManagerUI) {
        cgmManagerOnboardDelegate?.cgmManagerOnboardNotifying(didOnboardCGMManager: cgmManager)
    }

    open func preferredGlucoseUnitDidChange(to preferredGlucoseUnit: HKUnit) {
        rootViewController.preferredGlucoseUnitDidChange(to: preferredGlucoseUnit)
    }
}

open class PumpManagerSettingsNavigationViewController: SettingsNavigationViewController, PumpManagerOnboardNotifying {

    open weak var pumpManagerOnboardDelegate: PumpManagerOnboardDelegate?

    open func notifySetup(pumpManager: PumpManagerUI, withFinalSettings settings: PumpManagerSetupSettings) {
        pumpManagerOnboardDelegate?.pumpManagerOnboardNotifying(didOnboardPumpManager: pumpManager, withFinalSettings: settings)
    }

}
