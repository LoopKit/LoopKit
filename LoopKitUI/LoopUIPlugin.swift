//
//  LoopUIPlugin.swift
//  LoopKitUI
//
//  Created by Pete Schwamb on 7/24/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol LoopUIPlugin {
    var pumpManagerType: PumpManagerUI.Type? { get }
    var cgmManagerType: CGMManagerUI.Type? { get }
}
