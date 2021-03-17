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

public protocol ServiceUI: Service {
    /// The image for this type of service.
    static var image: UIImage? { get }

    /// Create and onboard a new service.
    ///
    /// - Parameters:
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: Either a conforming view controller to create and onboard the service or a newly created and onboarded service.
    static func setupViewController(colorPalette: LoopUIColorPalette) -> SetupUIResult<UIViewController & ServiceCreateNotifying & ServiceOnboardNotifying & CompletionNotifying, ServiceUI>

    /// Configure settings for an existing service.
    ///
    /// - Parameters:
    ///     - colorPalette: Color palette to use for any UI.
    /// - Returns: A view controller to configure an existing service.
    func settingsViewController(colorPalette: LoopUIColorPalette) -> (UIViewController & ServiceOnboardNotifying & CompletionNotifying)
}

public extension ServiceUI {
    var image: UIImage? { return type(of: self).image }
}

public protocol ServiceCreateDelegate: AnyObject {
    /// Informs the delegate that the specified service was created.
    ///
    /// - Parameters:
    ///     - service: The service created.
    func serviceCreateNotifying(didCreateService service: Service)
}

public protocol ServiceCreateNotifying {
    /// Delegate to notify about service creation.
    var serviceCreateDelegate: ServiceCreateDelegate? { get set }
}

public protocol ServiceOnboardDelegate: AnyObject {
    /// Informs the delegate that the specified service was onboarded.
    ///
    /// - Parameters:
    ///     - service: The service onboarded.
    func serviceOnboardNotifying(didOnboardService service: Service)
}

public protocol ServiceOnboardNotifying {
    /// Delegate to notify about service onboarding.
    var serviceOnboardDelegate: ServiceOnboardDelegate? { get set }
}
