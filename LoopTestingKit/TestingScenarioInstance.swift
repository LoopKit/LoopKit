//
//  TestingScenarioInstance.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 4/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

public enum InjectedAction: String {
    case test // TODO: delete once actions are defined in future scenario tickets
}

public struct TestingScenarioInstance {
    public var pastGlucoseSamples: [NewGlucoseSample]
    public var futureGlucoseSamples: [NewGlucoseSample]
    public var pumpEvents: [NewPumpEvent]
    public var carbEntries: [NewCarbEntry]
    public var injectedActions: [InjectedAction]
    
    public var hasCGMData: Bool {
        !(pastGlucoseSamples + futureGlucoseSamples).isEmpty
    }
    
    public var hasPumpData: Bool {
        !pumpEvents.isEmpty
    }
}
