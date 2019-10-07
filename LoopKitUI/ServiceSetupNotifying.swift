//
//  ServiceSetupNotifying.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 9/30/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

public protocol ServiceSetupDelegate: AnyObject {

    /// Informs the delegate that the specified service was created.
    ///
    /// - Parameters:
    ///     - service: The service created.
    func serviceSetupNotifying(_ object: ServiceSetupNotifying, didCreateService service: Service)

    /// Informs the delegate that the specified service was updated.
    /// An existing service is considered updated when the credentials,
    /// authorization, or any other configuration necessary for the
    /// service are changed.
    ///
    /// - Parameters:
    ///     - service: The service updated.
    func serviceSetupNotifying(_ object: ServiceSetupNotifying, didUpdateService service: Service)

    /// Informs the delegate that the specified service was deleted.
    ///
    /// - Parameters:
    ///     - service: The service deleted.
    func serviceSetupNotifying(_ object: ServiceSetupNotifying, didDeleteService service: Service)

}

public protocol ServiceSetupNotifying: AnyObject {

    /// Delegate to notify about service changes.
    var serviceSetupDelegate: ServiceSetupDelegate? { get set }

}

