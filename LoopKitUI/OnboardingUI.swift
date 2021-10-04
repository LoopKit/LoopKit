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

public enum NotificationAuthorization: Int {
    /// User has not yet made a choice regarding whether the application may schedule or receive user notifications.
    case notDetermined

    /// User has explicitly denied this application from scheduling or receiving user notifications.
    case denied

    /// User has authorized this application to schedule or receive non-interruptive user notifications.
    case provisional

    /// User has authorized this application to schedule or receive any user notifications.
    case authorized
}

public protocol NotificationAuthorizationProvider: AnyObject {
    /// The current notification authorization.
    ///
    /// - Parameters:
    ///     - completion: Invoked when notification authorization is available.
    func getNotificationAuthorization(_ completion: @escaping (NotificationAuthorization) -> Void)

    /// Authorize notification. Should only be invoked if notificationAuthorization is .notDetermined.
    ///
    /// - Parameters:
    ///     - completion: Invoked when notification authorization is complete along with the resulting authorization.
    func authorizeNotification(_ completion: @escaping (NotificationAuthorization) -> Void)
}

public enum HealthStoreAuthorization: Int {
    /// User has not yet made a choice regarding permissions for one or more health store data types.
    case notDetermined

    /// User has explicitly chosen permissions for each health store data type.
    case determined
}

public protocol HealthStoreAuthorizationProvider: AnyObject {
    /// The current health store authorization.
    ///
    /// - Parameters:
    ///     - completion: Invoked when health store authorization is available.
    func getHealthStoreAuthorization(_ completion: @escaping (HealthStoreAuthorization) -> Void)

    /// Authorize health store. Should only be invoked if healthStoreAuthorization is .notDetermined.
    ///
    /// - Parameters:
    ///     - completion: Invoked when health store authorization is complete along with the resulting authorization.
    func authorizeHealthStore(_ completion: @escaping (HealthStoreAuthorization) -> Void)
}

public typealias OnboardingResult = SetupUIResult

public protocol CGMManagerProvider: AnyObject {
    /// The active CGM manager.
    var activeCGMManager: CGMManager? { get }

    /// The descriptor list of available CGM managers.
    var availableCGMManagers: [CGMManagerDescriptor] { get }

    /// An image for the CGM manager with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the CGM manager.
    /// - Returns: An image for the CGM manager with the specified identifier.
    func imageForCGMManager(withIdentifier identifier: String) -> UIImage?

    /// Onboard the CGM manager with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the CGM manager to onboard.
    /// - Returns: Either a conforming view controller to onboard the CGM manager, a newly onboarded CGM manager, or an error.
    func onboardCGMManager(withIdentifier identifier: String) -> Result<OnboardingResult<CGMManagerViewController, CGMManager>, Error>
}

public protocol PumpManagerProvider: AnyObject {
    /// The active pump manager.
    var activePumpManager: PumpManager? { get }

    /// The descriptor list of available pump managers.
    var availablePumpManagers: [PumpManagerDescriptor] { get }

    /// An image for the pump manager with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the pump manager.
    /// - Returns: An image for the pump manager with the specified identifier.
    func imageForPumpManager(withIdentifier identifier: String) -> UIImage?

    /// An supported increments for the pump manager with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the pump manager.
    /// - Returns: An supported increments for the pump manager with the specified identifier.
    func supportedIncrementsForPumpManager(withIdentifier identifier: String) -> PumpSupportedIncrements?

    /// Onboard the pump manager with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the pump manager to onboard.
    /// - Returns: Either a conforming view controller to onboard the pump manager, a newly onboarded pump manager, or an error.
    func onboardPumpManager(withIdentifier identifier: String, initialSettings settings: PumpManagerSetupSettings) -> Result<OnboardingResult<PumpManagerViewController, PumpManager>, Error>
}

public protocol ServiceProvider: AnyObject {
    /// The active services.
    var activeServices: [Service] { get }

    /// The descriptor list of available services.
    var availableServices: [ServiceDescriptor] { get }

    /// Onboard the service with the specified identifier.
    ///
    /// - Parameters:
    ///     - identifier: The identifier of the service to onboard.
    /// - Returns: Either a conforming view controller to onboard the service, a newly onboarded service, or an error.
    func onboardService(withIdentifier identifier: String) -> Result<OnboardingResult<ServiceViewController, Service>, Error>
}

public protocol TherapySettingsProvider {
    var onboardingTherapySettings: TherapySettings { get }
}

public protocol OnboardingProvider: NotificationAuthorizationProvider, HealthStoreAuthorizationProvider, BluetoothProvider, CGMManagerProvider, PumpManagerProvider, ServiceProvider, TherapySettingsProvider {
    var allowDebugFeatures: Bool { get }   // NOTE: DEBUG FEATURES - DEBUG AND TEST ONLY
}

public protocol OnboardingDelegate: AnyObject {
    /// Informs the delegate that the state of the onboarding was updated and the delegate should persist the onboarding. May
    /// be invoked prior to the onboarding being fully complete.
    ///
    /// - Parameters:
    ///     - onboarding: The onboarding that updated state.
    func onboardingDidUpdateState(_ onboarding: OnboardingUI)

    /// Informs the delegate that onboarding has new therapy settings that should be persisted.
    ///
    /// - Parameters:
    ///     - onboarding: The onboarding that has new therapy settings.
    ///     - therapySettings: The new therapy settings.
    func onboarding(_ onboarding: OnboardingUI, hasNewTherapySettings therapySettings: TherapySettings)

    /// Informs the delegate that onboarding has new dosing enabled that should be persisted.
    ///
    /// - Parameters:
    ///     - onboarding: The onboarding that has new dosing enabled.
    ///     - isClosedLoop: The new dosing enabled.
    func onboarding(_ onboarding: OnboardingUI, hasNewDosingEnabled dosingEnabled: Bool)

    /// Informs the delegate the onboarding has suspended.
    ///
    /// - Parameters:
    ///     - onboarding: The onboarding that has suspended.
    func onboardingDidSuspend(_ onboarding: OnboardingUI)
}

public typealias OnboardingViewController = (UIViewController & CGMManagerOnboarding & PumpManagerOnboarding & ServiceOnboarding & CompletionNotifying)

public protocol OnboardingUI: AnyObject {
    typealias RawState = [String: Any]

    /// Create a new onboarding.
    ///
    /// - Returns: A newly created onboarding.
    static func createOnboarding() -> OnboardingUI

    /// Delegate to notify about onboarding changes.
    var onboardingDelegate: OnboardingDelegate? { get set }

    /// The unique identifier of this type of onboarding.
    var onboardingIdentifier: String { get }

    /// Initializes the onboarding with the previously-serialized state.
    ///
    /// - Parameters:
    ///     - rawState: The previously-serialized state of the onboarding.
    init?(rawState: RawState)

    /// The current, serializable state of the onboarding.
    var rawState: RawState { get }

    /// Is the onboarding complete?
    var isOnboarded: Bool { get }

    /// Provides a view controller to configure onboarding, if needed.
    ///
    /// - Parameters:
    ///   - onboardingProvider: The provider of auxillary services that support onboarding.
    ///   - displayGlucoseUnitObservable: The glucose unit to use for display.
    ///   - colorPalette: The colors to use in any UI,
    /// - Returns: A view controller to create and configure a new onboarding.
    func onboardingViewController(onboardingProvider: OnboardingProvider, displayGlucoseUnitObservable: DisplayGlucoseUnitObservable, colorPalette: LoopUIColorPalette) -> OnboardingViewController
}
