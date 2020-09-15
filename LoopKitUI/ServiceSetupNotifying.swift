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

}

public protocol ServiceSetupNotifying: AnyObject {

    /// Delegate to notify about service setup.
    var serviceSetupDelegate: ServiceSetupDelegate? { get set }

}

public protocol ServiceSettingsDelegate: AnyObject {

    /// Informs the delegate that the specified service was deleted.
    ///
    /// - Parameters:
    ///     - service: The service deleted.
    func serviceSettingsNotifying(_ object: ServiceSettingsNotifying, didDeleteService service: Service)

}

public protocol ServiceSettingsNotifying: AnyObject {

    /// Delegate to notify about service settings.
    var serviceSettingsDelegate: ServiceSettingsDelegate? { get set }

}
