//
//  TestingCGMManager.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 3/5/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit


public protocol TestingCGMManager: CGMManager, TestingDeviceManager {
    func injectGlucoseSamples(_ samples: [NewGlucoseSample])
}
