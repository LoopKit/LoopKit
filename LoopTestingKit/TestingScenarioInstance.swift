//
//  TestingScenarioInstance.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 4/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

public struct NewDeviceAction: Equatable {
    public let name: String
    public let date: Date
}

public struct TestingScenarioInstance {
    public var pastGlucoseSamples: [NewGlucoseSample]
    public var futureGlucoseSamples: [NewGlucoseSample]
    public var pumpEvents: [NewPumpEvent]
    public var carbEntries: [NewCarbEntry]
    public var injectedActions: [NewDeviceAction]
    
    public var hasCGMData: Bool {
        !(pastGlucoseSamples + futureGlucoseSamples).isEmpty
    }
    
    public var hasPumpData: Bool {
        !pumpEvents.isEmpty
    }
}
