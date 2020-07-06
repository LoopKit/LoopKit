//
//  DeviceLifecycleProgressState.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-07-03.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum DeviceLifecycleProgressState: Int, CaseIterable {
    case normal
    case warning
    case critical
}
