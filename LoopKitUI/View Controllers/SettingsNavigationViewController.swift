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

open class CGMManagerSettingsNavigationViewController: SettingsNavigationViewController, CGMManagerOnboarding {

    open weak var cgmManagerOnboardingDelegate: CGMManagerOnboardingDelegate?

    open func notifySetup(cgmManager: CGMManagerUI) {
        cgmManagerOnboardingDelegate?.cgmManagerOnboarding(didOnboardCGMManager: cgmManager)
    }

}

open class PumpManagerSettingsNavigationViewController: SettingsNavigationViewController, PumpManagerOnboarding {

    open weak var pumpManagerOnboardingDelegate: PumpManagerOnboardingDelegate?

    open func notifySetup(pumpManager: PumpManagerUI, withFinalSettings settings: PumpManagerSetupSettings) {
        pumpManagerOnboardingDelegate?.pumpManagerOnboarding(didOnboardPumpManager: pumpManager, withFinalSettings: settings)
    }

}
