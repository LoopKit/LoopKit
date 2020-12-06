//
//  UnfinalizedDose.swift
//  MockKit
//
//  Created by Pete Schwamb on 7/30/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

public struct UnfinalizedDose: RawRepresentable, Equatable, CustomStringConvertible {
    public typealias RawValue = [String: Any]

    enum DoseType: Int {
        case bolus = 0
        case tempBasal
        case suspend
        case resume
    }

    private let dateFormatter = ISO8601DateFormatter()

    private let insulinFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    fileprivate var uniqueKey: Data {
        return "\(doseType) \(scheduledUnits ?? units) \(dateFormatter.string(from: startTime))".data(using: .utf8)!
    }

    let doseType: DoseType
    public var units: Double
    var scheduledUnits: Double?     // Tracks the scheduled units, as boluses may be canceled before finishing, at which point units would reflect actual delivered volume.
    var scheduledTempRate: Double?  // Tracks the original temp rate, as during finalization the units are discretized to pump pulses, changing the actual rate
    let startTime: Date
    var duration: TimeInterval

    var finishTime: Date {
        get {
            return startTime.addingTimeInterval(duration)
        }
        set {
            duration = newValue.timeIntervalSince(startTime)
        }
    }

    public var progress: Double {
        let elapsed = -startTime.timeIntervalSinceNow
        return min(elapsed / duration, 1)
    }

    public var finished: Bool {
        return progress >= 1
    }

    // Units per hour
    public var rate: Double {
        guard duration.hours > 0 else {
            return 0
        }
        return units / duration.hours
    }

    public var finalizedUnits: Double? {
        guard finished else {
            return nil
        }
        return units
    }

    init(bolusAmount: Double, startTime: Date, duration: TimeInterval) {
        self.doseType = .bolus
        self.units = bolusAmount
        self.startTime = startTime
        self.duration = duration
        self.scheduledUnits = nil
    }

    init(tempBasalRate: Double, startTime: Date, duration: TimeInterval) {
        self.doseType = .tempBasal
        self.units = tempBasalRate * duration.hours
        self.startTime = startTime
        self.duration = duration
        self.scheduledUnits = nil
    }

    init(suspendStartTime: Date) {
        self.doseType = .suspend
        self.units = 0
        self.startTime = suspendStartTime
        self.duration = 0
    }

    init(resumeStartTime: Date) {
        self.doseType = .resume
        self.units = 0
        self.startTime = resumeStartTime
        self.duration = 0
    }

    public mutating func cancel(at date: Date) {
        guard date < finishTime else {
            return
        }

        scheduledUnits = units
        let newDuration = date.timeIntervalSince(startTime)

        switch doseType {
        case .bolus:
            units = rate * newDuration.hours
        case .tempBasal:
            scheduledTempRate = rate
            units = floor(rate * newDuration.hours * 20) / 20
        default:
            break
        }
        duration = newDuration
    }

    public var isMutable: Bool {
        switch doseType {
        case .bolus, .tempBasal:
            return !finished
        default:
            return false
        }
    }

    public var description: String {
        let unitsStr = insulinFormatter.string(from: NSNumber(value:units)) ?? "?"
        switch doseType {
        case .bolus:
            if let scheduledUnits = scheduledUnits,
               let scheduledUnitsStr = insulinFormatter.string(from: NSNumber(value:scheduledUnits))
            {
                return "Interrupted Bolus units:\(unitsStr) (\(scheduledUnitsStr) scheduled) startTime:\(startTime) duration:\(String(describing: duration))"
            } else {
                return "Bolus units:\(unitsStr) startTime:\(startTime) duration:\(String(describing: duration))"
            }
        case .tempBasal:
            return "Temp Basal rate:\(scheduledTempRate ?? rate) units:\(unitsStr) startTime:\(startTime) duration:\(String(describing: duration))"
        case .suspend, .resume:
            return "\(doseType) startTime:\(startTime)"
        }
    }

    // RawRepresentable
    public init?(rawValue: RawValue) {
        guard
            let rawDoseType = rawValue["doseType"] as? Int,
            let doseType = DoseType(rawValue: rawDoseType),
            let units = rawValue["units"] as? Double,
            let startTime = rawValue["startTime"] as? Date,
            let duration = rawValue["duration"] as? Double
            else {
                return nil
        }

        self.doseType = doseType
        self.units = units
        self.startTime = startTime
        self.duration = duration

        if let scheduledUnits = rawValue["scheduledUnits"] as? Double {
            self.scheduledUnits = scheduledUnits
        }

        if let scheduledTempRate = rawValue["scheduledTempRate"] as? Double {
            self.scheduledTempRate = scheduledTempRate
        }
    }

    public var rawValue: RawValue {
        var rawValue: RawValue = [
            "doseType": doseType.rawValue,
            "units": units,
            "startTime": startTime,
            "duration": duration,
        ]

        if let scheduledUnits = scheduledUnits {
            rawValue["scheduledUnits"] = scheduledUnits
        }

        if let scheduledTempRate = scheduledTempRate {
            rawValue["scheduledTempRate"] = scheduledTempRate
        }

        return rawValue
    }
}

extension NewPumpEvent {
    init(_ dose: UnfinalizedDose) {
        let title = String(describing: dose)
        let entry = DoseEntry(dose)
        self.init(date: dose.startTime, dose: entry, isMutable: dose.isMutable, raw: dose.uniqueKey, title: title)
    }

    public var unfinalizedDose: UnfinalizedDose? {
        if let dose = dose {
            let duration = dose.endDate.timeIntervalSince(dose.startDate)
            switch dose.type {
            case .basal:
                return nil
            case .bolus:
                var newDose = UnfinalizedDose(bolusAmount: dose.programmedUnits, startTime: dose.startDate, duration: duration)
                if let delivered = dose.deliveredUnits {
                    newDose.scheduledUnits = dose.programmedUnits
                    newDose.units = delivered
                }
                return newDose
            case .resume:
                return UnfinalizedDose(resumeStartTime: dose.startDate)
            case .suspend:
                return UnfinalizedDose(suspendStartTime: dose.startDate)
            case .tempBasal:
                return UnfinalizedDose(tempBasalRate: dose.unitsPerHour, startTime: dose.startDate, duration: duration)
            }
        }
        return nil
    }
}

extension DoseEntry {
    init (_ dose: UnfinalizedDose) {
        switch dose.doseType {
        case .bolus:
            self = DoseEntry(type: .bolus, startDate: dose.startTime, endDate: dose.finishTime, value: dose.scheduledUnits ?? dose.units, unit: .units, deliveredUnits: dose.finalizedUnits)
        case .tempBasal:
            self = DoseEntry(type: .tempBasal, startDate: dose.startTime, endDate: dose.finishTime, value: dose.scheduledTempRate ?? dose.rate, unit: .unitsPerHour, deliveredUnits: dose.finalizedUnits)
        case .suspend:
            self = DoseEntry(suspendDate: dose.startTime)
        case .resume:
            self = DoseEntry(resumeDate: dose.startTime)
        }
    }
}
