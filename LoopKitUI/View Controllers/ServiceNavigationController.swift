//
//  ServiceNavigationController.swift
//  LoopKitUI
//
//  Created by Darin Krauss on 5/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import UIKit

open class ServiceNavigationController: UINavigationController, ServiceOnboarding, CompletionNotifying {
    public weak var serviceOnboardingDelegate: ServiceOnboardingDelegate?
    public weak var completionDelegate: CompletionDelegate?

    public func notifyServiceCreated(_ service: Service) {
        serviceOnboardingDelegate?.serviceOnboarding(didCreateService: service)
    }

    public func notifyServiceOnboarded(_ service: Service) {
        serviceOnboardingDelegate?.serviceOnboarding(didOnboardService: service)
    }

    public func notifyServiceCreatedAndOnboarded(_ service: ServiceUI) {
        notifyServiceCreated(service)
        notifyServiceOnboarded(service)
    }

    public func notifyComplete() {
        completionDelegate?.completionNotifyingDidComplete(self)
    }
}
