//
//  Environment+AppName.swift
//  LoopUI
//
//  Created by Rick Pasetto on 7/1/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI

private struct AppNameKey: EnvironmentKey {
    // Reasonable default value, but the expectation is that this is overridden by the clients of LoopKit, e.g.
    // MyView().environment(\.appName, Bundle.main.bundleDisplayName)
    static let defaultValue = "Loop"
}

public extension EnvironmentValues {
    var appName: String {
        get { self[AppNameKey.self] }
        set { self[AppNameKey.self] = newValue }
    }
}
