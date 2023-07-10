//
//  TestingScenarioInstance.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 4/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

public struct TestingScenarioInstance {
    public var pastGlucoseSamples: [NewGlucoseSample]
    public var futureGlucoseSamples: [NewGlucoseSample]
    public var pumpEvents: [NewPumpEvent]
    public var carbEntries: [NewCarbEntry]
    public var deviceActions: [DeviceAction]
    public let shouldReloadManager: ReloadManager?
    
    public init(
        pastGlucoseSamples: [NewGlucoseSample],
        futureGlucoseSamples: [NewGlucoseSample],
        pumpEvents: [NewPumpEvent],
        carbEntries: [NewCarbEntry],
        deviceActions: [DeviceAction],
        shouldReloadManager: ReloadManager?
    ) {
        self.pastGlucoseSamples = pastGlucoseSamples
        self.futureGlucoseSamples = futureGlucoseSamples
        self.pumpEvents = pumpEvents
        self.carbEntries = carbEntries
        self.deviceActions = deviceActions
        self.shouldReloadManager = shouldReloadManager
    }
    
    public var hasCGMData: Bool {
        !(pastGlucoseSamples + futureGlucoseSamples).isEmpty
    }
    
    public var hasPumpData: Bool {
        !pumpEvents.isEmpty
    }
}
