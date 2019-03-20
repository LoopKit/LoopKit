//
//  TestingDeviceManager.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 3/5/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit
import HealthKit


public protocol TestingDeviceManager: DeviceManager {
    var testingDevice: HKDevice { get }
}
