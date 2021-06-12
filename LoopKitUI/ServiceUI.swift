//
//  ServiceUI.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopKit

public struct ServiceDescriptor {
    public let identifier: String
    public let localizedTitle: String

    public init(identifier: String, localizedTitle: String) {
        self.identifier = identifier
        self.localizedTitle = localizedTitle
    }
}

public typealias ServiceViewController = (UIViewController & ServiceOnboarding & CompletionNotifying)

public protocol ServiceUI: Service {
    /// The image for this type of service.
    static var image: UIImage? { get }

    /// Create and onboard a new service.
    ///
    /// - Parameters:
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: Either a conforming view controller to create and onboard the service or a newly created and onboarded service.
    static func setupViewController(colorPalette: LoopUIColorPalette) -> SetupUIResult<ServiceViewController, ServiceUI>

    /// Configure settings for an existing service.
    ///
    /// - Parameters:
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: A view controller to configure an existing service.
    func settingsViewController(colorPalette: LoopUIColorPalette) -> ServiceViewController
}

public extension ServiceUI {
    var image: UIImage? { return type(of: self).image }
}

public protocol ServiceOnboardingDelegate: AnyObject {
    /// Informs the delegate that the specified service was created.
    ///
    /// - Parameters:
    ///     - service: The service created.
    func serviceOnboarding(didCreateService service: Service)

    /// Informs the delegate that the specified service was onboarded.
    ///
    /// - Parameters:
    ///     - service: The service onboarded.
    func serviceOnboarding(didOnboardService service: Service)
}

public protocol ServiceOnboarding {
    /// Delegate to notify about service onboarding.
    var serviceOnboardingDelegate: ServiceOnboardingDelegate? { get set }
}
