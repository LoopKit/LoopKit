//
//  TestingScenarioInstance.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 4/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit

public struct TestingScenarioInstance: RawRepresentable {
    
    public typealias RawValue = [String: Any]
    
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
        shouldReloadManager: ReloadManager? = nil
    ) {
        self.pastGlucoseSamples = pastGlucoseSamples
        self.futureGlucoseSamples = futureGlucoseSamples
        self.pumpEvents = pumpEvents
        self.carbEntries = carbEntries
        self.deviceActions = deviceActions
        self.shouldReloadManager = shouldReloadManager
    }
    
    public init?(rawValue: [String : Any]) {
        self.pastGlucoseSamples = (rawValue["pastGlucoseSamples"] as? [NewGlucoseSample.RawValue])?.compactMap { NewGlucoseSample(rawValue: $0) } ?? []
        self.futureGlucoseSamples = (rawValue["futureGlucoseSamples"] as? [NewGlucoseSample.RawValue])?.compactMap { NewGlucoseSample(rawValue: $0) } ?? []
        self.pumpEvents = (rawValue["pumpEvents"] as? [NewPumpEvent.RawValue])?.compactMap { NewPumpEvent(rawValue: $0) } ?? []
        self.carbEntries = (rawValue["carbEntries"] as? [NewCarbEntry.RawValue])?.compactMap { NewCarbEntry(rawValue: $0) } ?? []
        self.deviceActions = (rawValue["deviceActions"] as? [DeviceAction.RawValue])?.compactMap { DeviceAction(rawValue: $0) } ?? []
        self.shouldReloadManager = rawValue["shouldReloadManager"] as? ReloadManager ?? nil
    }
    
    public var rawValue: [String : Any] {
        var rawValue: [String: Any] = [:]
        
        rawValue["pastGlucoseSamples"] = pastGlucoseSamples.map(\.rawValue)
        rawValue["futureGlucoseSamples"] = futureGlucoseSamples.map(\.rawValue)
        rawValue["pumpEvents"] = pumpEvents.map(\.rawValue)
        rawValue["carbEntries"] = carbEntries.map(\.rawValue)
        rawValue["deviceActions"] = deviceActions.map(\.rawValue)
        rawValue["shouldReloadManager"] = shouldReloadManager?.rawValue
        
        return rawValue
    }
    
    public var hasCGMData: Bool {
        !(pastGlucoseSamples + futureGlucoseSamples).isEmpty
    }
    
    public var hasPumpData: Bool {
        !pumpEvents.isEmpty
    }
}

public extension TestingScenarioInstance {
    static var thirteenHourTrace: TestingScenarioInstance {
        guard let scenarioURLs = try? FileManager.default.contentsOfDirectory(at: Bundle.main.bundleURL.appendingPathComponent("Scenarios"), includingPropertiesForKeys: nil).filter({ $0.pathExtension == "json" }), let url = scenarioURLs.first(where: { $0.lastPathComponent.contains("13-hour-BG-trace") }), let scenario = try? TestingScenario(source: url).instantiate() else {
            return TestingScenarioInstance(pastGlucoseSamples: [], futureGlucoseSamples: [], pumpEvents: [], carbEntries: [], deviceActions: [])
        }
        
        return scenario
    }
}
