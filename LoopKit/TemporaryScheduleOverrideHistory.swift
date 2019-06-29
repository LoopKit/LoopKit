//
//  TemporaryScheduleOverrideHistory.swift
//  LoopKit
//
//  Created by Michael Pangburn on 3/25/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


private struct OverrideEvent: Equatable {
    enum End: Equatable {
        case natural
        case early(Date)
    }

    var override: TemporaryScheduleOverride
    var end: End = .natural

    init(override: TemporaryScheduleOverride) {
        self.override = override
    }

    var actualEndDate: Date {
        switch end {
        case .natural:
            return override.endDate
        case .early(let endDate):
            return endDate
        }
    }
}


public protocol TemporaryScheduleOverrideHistoryDelegate: AnyObject {
    func temporaryScheduleOverrideHistoryDidUpdate(_ history: TemporaryScheduleOverrideHistory)
}

public final class TemporaryScheduleOverrideHistory {
    private var recentEvents: [OverrideEvent] = [] {
        didSet {
            delegate?.temporaryScheduleOverrideHistoryDidUpdate(self)

            if let lastTaintedEvent = taintedEventLog.last,
                Date().timeIntervalSince(lastTaintedEvent.override.startDate) > .hours(48)
            {
                taintedEventLog.removeAll()
            }

        }
    }

    /// Tracks a sequence of override events that failed validation checks.
    /// Stored to enable retrieval via issue report after a deliberate crash.
    private var taintedEventLog: [OverrideEvent] = [] {
        didSet {
            delegate?.temporaryScheduleOverrideHistoryDidUpdate(self)
        }
    }

    public weak var delegate: TemporaryScheduleOverrideHistoryDelegate?

    public init() {}

    public func recordOverride(_ override: TemporaryScheduleOverride?, at enableDate: Date = Date()) {
        guard override != recentEvents.last?.override else {
            return
        }

        if let override = override {
            record(override, at: enableDate)
        } else {
            cancelActiveOverride(at: enableDate)
        }
    }

    private func record(_ override: TemporaryScheduleOverride, at enableDate: Date) {
        recentEvents.removeAll(where: { $0.override.startDate >= override.startDate })

        if recentEvents.last?.override.hasFinished(relativeTo: enableDate) == false {
            let overrideEnd = min(override.startDate.nearestPrevious, enableDate)
            recentEvents[recentEvents.endIndex - 1].end = .early(overrideEnd)
        }

        let enabledEvent = OverrideEvent(override: override)
        recentEvents.append(enabledEvent)
    }

    private func cancelActiveOverride(at date: Date) {
        if  let lastEvent = recentEvents.last,
            case .natural = lastEvent.end,
            !lastEvent.override.hasFinished(relativeTo: date)
        {
            if lastEvent.override.startDate > date {
                recentEvents.removeLast()
            } else {
                recentEvents[recentEvents.endIndex - 1].end = .early(date)
            }
        }
    }

    public func resolvingRecentBasalSchedule(_ base: BasalRateSchedule, relativeTo referenceDate: Date = Date()) -> BasalRateSchedule {
        filterRecentEvents(relativeTo: referenceDate)
        return overridesReflectingEnabledDuration(relativeTo: referenceDate).reduce(base) { base, override in
            base.applyingBasalRateMultiplier(from: override, relativeTo: referenceDate)
        }
    }

    public func resolvingRecentInsulinSensitivitySchedule(_ base: InsulinSensitivitySchedule, relativeTo referenceDate: Date = Date()) -> InsulinSensitivitySchedule {
        filterRecentEvents(relativeTo: referenceDate)
        return overridesReflectingEnabledDuration(relativeTo: referenceDate).reduce(base) { base, override in
            base.applyingSensitivityMultiplier(from: override, relativeTo: referenceDate)
        }
    }

    public func resolvingRecentCarbRatioSchedule(_ base: CarbRatioSchedule, relativeTo referenceDate: Date = Date()) -> CarbRatioSchedule {
        filterRecentEvents(relativeTo: referenceDate)
        return overridesReflectingEnabledDuration(relativeTo: referenceDate).reduce(base) { base, override in
            base.applyingCarbRatioMultiplier(from: override, relativeTo: referenceDate)
        }
    }

    private func relevantPeriod(relativeTo referenceDate: Date) -> DateInterval {
        let window = CarbStore.defaultMaximumAbsorptionTimeInterval
        return DateInterval(
            start: referenceDate.addingTimeInterval(-window),
            end: referenceDate.addingTimeInterval(window)
        )
    }

    private func filterRecentEvents(relativeTo referenceDate: Date) {
        let period = relevantPeriod(relativeTo: referenceDate)
        var recentEvents = self.recentEvents
        recentEvents.removeAll(where: { event in
            event.actualEndDate < period.start || event.override.startDate > period.end
        })

        if recentEvents != self.recentEvents {
            self.recentEvents = recentEvents
        }
    }

    private func overridesReflectingEnabledDuration(relativeTo referenceDate: Date) -> [TemporaryScheduleOverride] {
        var overrides = recentEvents.map { event -> TemporaryScheduleOverride in
            var override = event.override
            if case .early(let endDate) = event.end {
                override.endDate = endDate
            }
            return override
        }
        let period = relevantPeriod(relativeTo: referenceDate)
        overrides.mutateEach { override in
            // Save the actual (computed) end date prior to modifying the start date, which shifts the whole interval
            let end = override.endDate
            override.startDate = max(override.startDate, period.start)
            override.endDate = min(end, period.end)
        }
        validateOverridesReflectingEnabledDuration(overrides)
        return overrides
    }

    private func validateOverridesReflectingEnabledDuration(_ overrides: [TemporaryScheduleOverride]) {
        let overlappingOverridePairIndices: [(Int, Int)] =
            Array(overrides.enumerated())
                .allPairs()
                .compactMap {
                    let ((index1, override1), (index2, override2)) = ($0, $1)
                    if override1.activeInterval.intersects(override2.activeInterval) {
                        return (index1, index2)
                    } else {
                        return nil
                    }
                }

        let invalidOverrideIndices = overlappingOverridePairIndices.flatMap { [$0, $1] }
        guard invalidOverrideIndices.isEmpty else {
            // Save the invalid event history for debugging.
            taintedEventLog = recentEvents

            // Wipe only conflicting overrides to retain as much history as possible.
            recentEvents.removeAll(at: invalidOverrideIndices)

            // Crash deliberately to notify something has gone wrong.
            preconditionFailure("No overrides should overlap.")
        }
    }

    func wipeHistory() {
        recentEvents.removeAll()
    }
}


extension OverrideEvent: RawRepresentable {
    typealias RawValue = [String: Any]

    init?(rawValue: RawValue) {
        guard
            let overrideRawValue = rawValue["override"] as? TemporaryScheduleOverride.RawValue,
            let override = TemporaryScheduleOverride(rawValue: overrideRawValue)
        else {
            return nil
        }

        self.override = override

        if let endDate = rawValue["endDate"] as? Date {
            self.end = .early(endDate)
        }
    }

    var rawValue: RawValue {
        var raw: RawValue = [
            "override": override.rawValue
        ]

        if case .early(let endDate) = end {
            raw["endDate"] = endDate
        }

        return raw
    }
}


extension TemporaryScheduleOverrideHistory: RawRepresentable {
    public typealias RawValue = [String: [[String: Any]]]

    public convenience init?(rawValue: RawValue) {
        self.init()
        if let recentEventsRawValue = rawValue["recentEvents"] {
            let recentEvents = recentEventsRawValue.compactMap(OverrideEvent.init(rawValue:))
            guard recentEvents.count == recentEventsRawValue.count else {
                return nil
            }
            self.recentEvents = recentEvents
        }
        if let taintedEventsRawValue = rawValue["taintedEventLog"] {
            let taintedEventLog = taintedEventsRawValue.compactMap(OverrideEvent.init(rawValue:))
            guard taintedEventLog.count == taintedEventsRawValue.count else {
                return nil
            }
            self.taintedEventLog = taintedEventLog
        }
    }

    public var rawValue: RawValue {
        return [
            "recentEvents": recentEvents.map { $0.rawValue },
            "taintedEventLog": taintedEventLog.map { $0.rawValue }
        ]
    }
}


extension TemporaryScheduleOverrideHistory: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "TemporaryScheduleOverrideHistory(recentEvents: \(recentEvents), taintedEventLog: \(taintedEventLog))"
    }
}


private extension Date {
    var nearestPrevious: Date {
        return Date(timeIntervalSince1970: timeIntervalSince1970.nextDown)
    }
}
