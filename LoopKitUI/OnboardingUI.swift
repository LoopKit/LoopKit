//
//  OnboardingUI.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 12/10/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit

public protocol CGMManagerProvider: AnyObject {
    /// The active CGM manager.
    var activeCGMManager: CGMManager? { get }

    /// The descriptor list of available CGM managers.
    var availableCGMManagers: [CGMManagerDescriptor] { get }

    /// Setup the CGM manager with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the CGM manager to setup.
    /// - Returns: Either a conforming view controller to create and setup the CGM manager, a newly created and setup CGM manager, or an error.
    func setupCGMManager(withIdentifier identifier: String) -> Result<SetupUIResult<UIViewController & CGMManagerCreateNotifying & CGMManagerOnboardNotifying & CompletionNotifying, CGMManager>, Error>
}

public protocol PumpManagerProvider: AnyObject {
    /// The active pump manager.
    var activePumpManager: PumpManager? { get }

    /// The descriptor list of available pump managers.
    var availablePumpManagers: [PumpManagerDescriptor] { get }

    /// Setup the pump manager with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the pump manager to setup.
    /// - Returns: Either a conforming view controller to create and setup the pump manager, a newly created and setup pump manager, or an error.
    func setupPumpManager(withIdentifier identifier: String, initialSettings settings: PumpManagerSetupSettings) -> Result<SetupUIResult<UIViewController & PumpManagerCreateNotifying & PumpManagerOnboardNotifying & CompletionNotifying, PumpManager>, Error>
}

public protocol ServiceProvider: AnyObject {
    /// The active services.
    var activeServices: [Service] { get }

    /// The descriptor list of available services.
    var availableServices: [ServiceDescriptor] { get }

    /// Setup the setup with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the setup to setup.
    /// - Returns: Either a conforming view controller to create and setup the service, a newly created and setup service, or an error.
    func setupService(withIdentifier identifier: String) -> Result<SetupUIResult<UIViewController & ServiceCreateNotifying & ServiceOnboardNotifying & CompletionNotifying, Service>, Error>
}

public protocol OnboardingDelegate: AnyObject {
    /// Informs the delegate that onboarding has new therapy settings that should be persisted.
    ///
    /// - Parameters:
    ///     - therapySettings: The new therapy settings.
    func onboardingNotifying(hasNewTherapySettings therapySettings: TherapySettings)
}

public protocol OnboardingNotifying: AnyObject {
    /// Delegate to notify about onboarding changes.
    var onboardingDelegate: OnboardingDelegate? { get set }
}

public typealias OnboardingViewController = (OnboardingNotifying & CGMManagerCreateNotifying & CGMManagerOnboardNotifying & PumpManagerCreateNotifying & PumpManagerOnboardNotifying & ServiceCreateNotifying & ServiceOnboardNotifying & CompletionNotifying)

public protocol OnboardingUI {
    /// The unique identifier of this type of onboarding.
    var onboardingIdentifier: String { get }

    /// Create a new onboarding.
    ///
    /// - Returns: A newly created onboarding.
    static func createOnboarding() -> OnboardingUI

    /// Provides a view controller to configure onboarding, if needed.
    ///
    /// - Parameters:
    ///   - preferredGlucoseUnit: The preferred glucose unit.
    ///   - cgmManagerProvider: The provider of CGM Manager functionality.
    ///   - pumpManagerProvider: The provider of Pump Manager functionality.
    ///   - serviceProvider: The provider of Service functionality.
    ///   - colorPalette: The colors to use in any UI,
    /// - Returns: A view controller to create and configure a new onboarding.
    func onboardingViewController(preferredGlucoseUnit: HKUnit,
                                  cgmManagerProvider: CGMManagerProvider,
                                  pumpManagerProvider: PumpManagerProvider,
                                  serviceProvider: ServiceProvider,
                                  colorPalette: LoopUIColorPalette) -> (UIViewController & OnboardingViewController)
}
