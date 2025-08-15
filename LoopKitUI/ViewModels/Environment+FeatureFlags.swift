//
//  Environment+Settings.swift
//  LoopKit
//
//  Created by Pete Schwamb on 8/14/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//

import SwiftUI

private struct DosingStrategySelectionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

public extension EnvironmentValues {
    var dosingStrategySelectionEnabled: Bool {
        get { self[DosingStrategySelectionEnabledKey.self] }
        set { self[DosingStrategySelectionEnabledKey.self] = newValue }
    }
}
