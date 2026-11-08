//
//  LoopUIPlugin.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 7/24/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

public protocol PumpManagerUIPlugin: PumpManagerPlugin {
    var pumpManagerType: PumpManagerUI.Type? { get }
}

extension PumpManagerUIPlugin {
    public var pumpManagerType: PumpManager.Type? { pumpManagerType as PumpManagerUI.Type? }
}

public protocol CGMManagerUIPlugin: CGMManagerPlugin {
    var cgmManagerType: CGMManagerUI.Type? { get }
}

extension CGMManagerUIPlugin {
    public var cgmManagerType: CGMManager.Type? { cgmManagerType as CGMManagerUI.Type? }
}

public protocol ServiceUIPlugin {
    var serviceType: ServiceUI.Type? { get }
}

public protocol OnboardingUIPlugin {
    var onboardingType: OnboardingUI.Type? { get }
}

public protocol SupportUIPlugin {
    @MainActor
    var support: SupportUI { get }
}
