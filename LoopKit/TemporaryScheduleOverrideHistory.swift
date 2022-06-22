//
//  TemporaryScheduleOverrideHistory.swift
//  LoopKit
//
//  Created by Michael Pangburn on 3/25/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public enum End: Equatable, Hashable, Codable {
    case natural
    case early(Date)
    case deleted // Ended before started
    
    private enum EndType: String, Decodable {
        case natural, early, deleted
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case date
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let endType = try container.decode(EndType.self, forKey: .type)
        
        switch endType {
        case .natural:
            self = .natural
        case .early:
            let date = try container.decode(Date.self, forKey: .date)
            self = .early(date)
        case .deleted:
            self = .deleted
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .natural:
            try container.encode(EndType.natural.rawValue, forKey: .type)
        case .early(let date):
            try container.encode(EndType.early.rawValue, forKey: .type)
            try container.encode(date, forKey: .date)
        case .deleted:
            try container.encode(EndType.deleted.rawValue, forKey: .type)
        }
    }
}

private struct OverrideEvent: Equatable {

    var override: TemporaryScheduleOverride
    var modificationCounter: Int64

    init(override: TemporaryScheduleOverride, modificationCounter: Int64) {
        self.override = override
        self.modificationCounter = modificationCounter
    }
}


public protocol TemporaryScheduleOverrideHistoryDelegate: AnyObject {
    func temporaryScheduleOverrideHistoryDidUpdate(_ history: TemporaryScheduleOverrideHistory)
}

public final class TemporaryScheduleOverrideHistory {
    public struct QueryAnchor: RawRepresentable {
        public typealias RawValue = [String: Any]

        internal var modificationCounter: Int64

        public init() {
            self.modificationCounter = 0
        }

        public init?(rawValue: RawValue) {
            guard let modificationCounter = rawValue["modificationCounter"] as? Int64 else {
                return nil
            }
            self.modificationCounter = modificationCounter
        }

        public var rawValue: RawValue {
            var rawValue: RawValue = [:]
            rawValue["modificationCounter"] = modificationCounter
            return rawValue
        }
    }

    private var recentEvents: [OverrideEvent] = [] {
        didSet {
            modificationCounter += 1

            if let lastTaintedEvent = taintedEventLog.last,
                Date().timeIntervalSince(lastTaintedEvent.override.startDate) > .hours(48)
            {
                taintedEventLog.removeAll()
            }
        }
    }
    
    /// Tracks a sequence of override events that failed validation checks.
    /// Stored to enable retrieval via issue report after a deliberate crash.
    private var taintedEventLog: [OverrideEvent] = []
    
    private var modificationCounter: Int64
    
    public var relevantTimeWindow: TimeInterval = TimeInterval.hours(10)

    public weak var delegate: TemporaryScheduleOverrideHistoryDelegate?

    public init() {
        modificationCounter = 0
    }

    public func recordOverride(_ override: TemporaryScheduleOverride?, at enableDate: Date = Date()) {
        guard override != lastUndeletedEvent?.override else {
            return
        }
        
        if let override = override {
            record(override, at: enableDate)
        } else {
            cancelActiveOverride(at: enableDate)
        }
        delegate?.temporaryScheduleOverrideHistoryDidUpdate(self)
    }
    
    private var lastUndeletedEvent: OverrideEvent? {
        return recentEvents.reversed().first { $0.override.actualEnd != .deleted }
    }
    
    private func deleteEventsStartingOnOrAfter(_ date: Date) {
        recentEvents.mutateEach { (event) in
            if event.override.startDate >= date {
                event.override.actualEnd = .deleted
                event.modificationCounter = modificationCounter
            }
        }
    }
    
    // Deletes overrides that start after the passed in override.
    private func record(_ override: TemporaryScheduleOverride, at enableDate: Date) {
        
        // Check for modification of existing entry
        var index = recentEvents.endIndex
        while index != recentEvents.startIndex {
            recentEvents.formIndex(before: &index)
            if recentEvents[index].override.syncIdentifier == override.syncIdentifier {
                recentEvents[index].override = override
                recentEvents[index].modificationCounter = modificationCounter
                return
            }
        }
        
        deleteEventsStartingOnOrAfter(override.startDate)
        
        let overrideEnd = min(override.startDate.nearestPrevious, enableDate)
        
        cancelActiveOverride(at: overrideEnd)

        let enabledEvent = OverrideEvent(override: override, modificationCounter: modificationCounter)
        recentEvents.append(enabledEvent)
    }

    private func cancelActiveOverride(at date: Date) {
        var index = recentEvents.endIndex
        while index != recentEvents.startIndex {
            recentEvents.formIndex(before: &index)
            
            if recentEvents[index].override.actualEnd != .deleted {
                if recentEvents[index].override.actualEndDate > date {
                    if recentEvents[index].override.startDate > date {
                        recentEvents[index].override.actualEnd = .deleted
                    } else {
                        recentEvents[index].override.actualEnd = .early(date)
                    }
                    recentEvents[index].modificationCounter = modificationCounter
                }
                break
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
    
    public func getEvents(relativeTo referenceDate: Date = Date()) -> [TemporaryScheduleOverride] {
        filterRecentEvents(relativeTo: referenceDate)
        return recentEvents.map { $0.override }
    }

    private func relevantPeriod(relativeTo referenceDate: Date) -> DateInterval {
        return DateInterval(
            start: referenceDate.addingTimeInterval(-relevantTimeWindow),
            end: referenceDate.addingTimeInterval(relevantTimeWindow)
        )
    }

    private func filterRecentEvents(relativeTo referenceDate: Date) {
        let period = relevantPeriod(relativeTo: referenceDate)
        var recentEvents = self.recentEvents
        recentEvents.removeAll(where: { event in
            event.override.actualEndDate < period.start || event.override.startDate > period.end
        })

        if recentEvents != self.recentEvents {
            self.recentEvents = recentEvents
        }
    }

    private func overridesReflectingEnabledDuration(relativeTo referenceDate: Date) -> [TemporaryScheduleOverride] {
        var overrides = recentEvents.filter({$0.override.actualEnd != .deleted}).map { event -> TemporaryScheduleOverride in
            var override = event.override
            if case .early(let endDate) = event.override.actualEnd {
                override.scheduledEndDate = endDate
            }
            return override
        }
        let period = relevantPeriod(relativeTo: referenceDate)
        overrides.mutateEach { override in
            // Save the actual (computed) end date prior to modifying the start date, which shifts the whole interval
            let end = override.scheduledEndDate
            override.startDate = max(override.startDate, period.start)
            override.scheduledEndDate = min(end, period.end)
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
        modificationCounter = 0
    }
    
    public func queryByAnchor(_ anchor: QueryAnchor?) -> (resultOverrides: [TemporaryScheduleOverride], deletedOverrides: [TemporaryScheduleOverride], newAnchor: QueryAnchor)  {
        var resultOverrides = [TemporaryScheduleOverride]()
        var deletedOverrides = [TemporaryScheduleOverride]()
        for event in recentEvents {
            if anchor == nil || event.modificationCounter >= anchor!.modificationCounter {
                var override = event.override
                if case .early(let endDate) = event.override.actualEnd {
                    override.scheduledEndDate = endDate
                }
                if event.override.actualEnd == .deleted {
                    deletedOverrides.append(override)
                } else {
                    resultOverrides.append(override)
                }
            }
        }
        var newAnchor = QueryAnchor()
        newAnchor.modificationCounter = modificationCounter
        return (resultOverrides: resultOverrides, deletedOverrides: deletedOverrides, newAnchor: newAnchor)
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
        
        self.modificationCounter = rawValue["modificationCounter"] as? Int64 ?? 0
        
        if let isDeleted = rawValue["isDeleted"] as? Bool, isDeleted {
            self.override.actualEnd = .deleted
        } else if let endDate = rawValue["endDate"] as? Date {
            self.override.actualEnd = .early(endDate)
        }
    }

    var rawValue: RawValue {
        var raw: RawValue = [
            "override": override.rawValue,
            "modificationCounter": modificationCounter,
            "isDeleted": override.actualEnd == .deleted,
        ]

        if case .early(let endDate) = override.actualEnd {
            raw["endDate"] = endDate
        }

        return raw
    }
}


extension TemporaryScheduleOverrideHistory: RawRepresentable {
    public typealias RawValue = [String: Any]

    public convenience init?(rawValue: RawValue) {
        self.init()
        if let recentEventsRawValue = rawValue["recentEvents"] as? [[String: Any]] {
            let recentEvents = recentEventsRawValue.compactMap(OverrideEvent.init(rawValue:))
            guard recentEvents.count == recentEventsRawValue.count else {
                return nil
            }
            self.recentEvents = recentEvents
        }
        if let taintedEventsRawValue = rawValue["taintedEventLog"] as? [[String: Any]] {
            let taintedEventLog = taintedEventsRawValue.compactMap(OverrideEvent.init(rawValue:))
            guard taintedEventLog.count == taintedEventsRawValue.count else {
                return nil
            }
            self.taintedEventLog = taintedEventLog
        }
        
        self.modificationCounter = rawValue["modificationCounter"] as? Int64 ?? 0
    }

    public var rawValue: RawValue {
        return [
            "recentEvents": recentEvents.map { $0.rawValue },
            "taintedEventLog": taintedEventLog.map { $0.rawValue },
            "modificationCounter": modificationCounter
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
