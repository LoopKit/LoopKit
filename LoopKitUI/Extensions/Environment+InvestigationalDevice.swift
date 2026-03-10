//
//  Environment+InvestigationalDevice.swift
//  LoopKitUI
//
//  Created by Cameron Ingham on 7/2/24.
//  Copyright © 2024 LoopKit Authors. All rights reserved.
//

import SwiftUI

private struct InvestigationalDeviceKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var isInvestigationalDevice: Bool {
        get { self[InvestigationalDeviceKey.self] }
        set { self[InvestigationalDeviceKey.self] = newValue }
    }
}
