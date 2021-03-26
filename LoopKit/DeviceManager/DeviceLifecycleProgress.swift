//
//  DeviceLifecycleProgress.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-30.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol DeviceLifecycleProgress {
    /// the percent complete of the progress for this device status. Expects a value between 0.0 and 1.0
    var percentComplete: Double { get }

    /// the status of the progress to provide guidance as to how to present the progress
    var progressState: DeviceLifecycleProgressState { get }
}

public enum DeviceLifecycleProgressState: String, Codable {
    case critical
    case dimmed
    case normalCGM
    case normalPump
    case warning
}
