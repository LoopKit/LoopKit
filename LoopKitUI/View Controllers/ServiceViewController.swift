//
//  ServiceViewController.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

open class ServiceViewController: UINavigationController, ServiceSetupNotifying, ServiceSettingsNotifying, CompletionNotifying {

    public weak var serviceSetupDelegate: ServiceSetupDelegate?

    public weak var serviceSettingsDelegate: ServiceSettingsDelegate?

    public weak var completionDelegate: CompletionDelegate?

    public func notifyServiceCreated(_ service: Service) {
        serviceSetupDelegate?.serviceSetupNotifying(self, didCreateService: service)
    }

    public func notifyServiceDeleted(_ service: Service) {
        serviceSettingsDelegate?.serviceSettingsNotifying(self, didDeleteService: service)
    }

    public func notifyComplete() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }

}
