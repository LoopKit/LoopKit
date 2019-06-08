//
//  TestingScenario.swift
//  LoopTestingKit
//
//  Created by Michael Pangburn on 4/20/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit


public struct TestingScenario {
    var dateRelativeGlucoseSamples: [DateRelativeGlucoseSample]
    var dateRelativeBasalEntries: [DateRelativeBasalEntry]
    var dateRelativeBolusEntries: [DateRelativeBolusEntry]
    var dateRelativeCarbEntries: [DateRelativeCarbEntry]

    public func instantiate(relativeTo referenceDate: Date = Date()) -> TestingScenarioInstance {
        let glucoseSamples = dateRelativeGlucoseSamples
            .map { $0.newGlucoseSample(relativeTo: referenceDate) }
            .filter { $0.date <= referenceDate }
        let basalEntries = dateRelativeBasalEntries.map { $0.newPumpEvent(relativeTo: referenceDate) }
        let bolusEntries = dateRelativeBolusEntries.map { $0.newPumpEvent(relativeTo: referenceDate) }
        let pumpEvents = (basalEntries + bolusEntries)
            .filter { $0.date <= referenceDate }
            .sorted(by: { $0.date < $1.date })
        let carbEntries = dateRelativeCarbEntries
            .filter { $0.enteredAt(relativeTo: referenceDate) <= referenceDate }
            .map { $0.newCarbEntry(relativeTo: referenceDate) }
        return TestingScenarioInstance(glucoseSamples: glucoseSamples, pumpEvents: pumpEvents, carbEntries: carbEntries)
    }

    public mutating func stepBackward(by offset: TimeInterval) {
        assert(offset > 0)
        shift(by: offset)
    }

    public mutating func stepForward(by offset: TimeInterval) {
        assert(offset > 0)
        shift(by: -offset)
    }

    public mutating func stepForward(
        unitsPerHour: Double,
        duration: TimeInterval,
        dateOffset: TimeInterval = 0,
        loopInterval: TimeInterval = 60 * 5 /* minutes */
    ) {
        precondition(duration > 0)
        dateRelativeBasalEntries.removeAll(where: { $0.dateOffset >= dateOffset })
        let basal = DateRelativeBasalEntry(unitsPerHourValue: unitsPerHour, dateOffset: dateOffset, duration: duration)
        dateRelativeBasalEntries.append(basal)
        stepForward(by: loopInterval)
    }

    mutating func shift(by offset: TimeInterval) {
        dateRelativeGlucoseSamples.mutateEach { $0.shift(by: offset) }
        dateRelativeBasalEntries.mutateEach { $0.shift(by: offset) }
        dateRelativeBolusEntries.mutateEach { $0.shift(by: offset) }
        dateRelativeCarbEntries.mutateEach { $0.shift(by: offset) }
    }
}

extension TestingScenario: Codable {
    public enum CodingKeys: String, CodingKey {
        case dateRelativeGlucoseSamples = "glucoseValues"
        case dateRelativeBasalEntries = "basalDoses"
        case dateRelativeBolusEntries = "bolusDoses"
        case dateRelativeCarbEntries = "carbEntries"
    }
}

extension TestingScenario {
    public init(source: URL) throws {
        let decoder = JSONDecoder()
        let data = try Data(contentsOf: source)
        self = try decoder.decode(TestingScenario.self, from: data)
    }
}
