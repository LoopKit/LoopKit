//
//  LoopUIPlugin.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 7/24/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

public protocol PumpManagerUIPlugin {
    var pumpManagerType: PumpManagerUI.Type? { get }
}

public protocol CGMManagerUIPlugin {
    var cgmManagerType: CGMManagerUI.Type? { get }
}

public protocol ServiceUIPlugin {
    var serviceType: ServiceUI.Type? { get }
}

public protocol LoopUIPlugin: PumpManagerUIPlugin, CGMManagerUIPlugin {}

// TODO: Remove LoopUIPlugin after updating OmniKitPlugin and MinimedKitPlugin in rileylink_ios to explicitly
// use PumpManagerUIPlugin and/or CGMManagerUIPlugin rather than LoopUIPlugin
