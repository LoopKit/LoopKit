//
//  MockPumpManagerState.swift
//  MockKit
//
//  Created by Pete Schwamb on 7/31/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public struct MockPumpManagerState {
    public var reservoirUnitsRemaining: Double
    public var tempBasalEnactmentShouldError: Bool
    public var bolusEnactmentShouldError: Bool
    public var deliverySuspensionShouldError: Bool
    public var deliveryResumptionShouldError: Bool
    public var maximumBolus: Double
    public var maximumBasalRatePerHour: Double
    public var suspendState: SuspendState
    public var pumpBatteryChargeRemaining: Double?
    public var occlusionDetected: Bool = false
    public var pumpErrorDetected: Bool = false

    public var unfinalizedBolus: UnfinalizedDose?
    public var unfinalizedTempBasal: UnfinalizedDose?

    var finalizedDoses: [UnfinalizedDose]

    public var dosesToStore: [UnfinalizedDose] {
        return finalizedDoses + [unfinalizedTempBasal, unfinalizedBolus].compactMap {$0}
    }

    public mutating func finalizeFinishedDoses() {
        if let bolus = unfinalizedBolus, bolus.finished {
            finalizedDoses.append(bolus)
            unfinalizedBolus = nil
        }

        if let tempBasal = unfinalizedTempBasal, tempBasal.finished {
            finalizedDoses.append(tempBasal)
            unfinalizedTempBasal = nil
        }
    }
}


extension MockPumpManagerState: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard let reservoirUnitsRemaining = rawValue["reservoirUnitsRemaining"] as? Double else {
            return nil
        }

        self.reservoirUnitsRemaining = reservoirUnitsRemaining
        self.tempBasalEnactmentShouldError = rawValue["tempBasalEnactmentShouldError"] as? Bool ?? false
        self.bolusEnactmentShouldError = rawValue["bolusEnactmentShouldError"] as? Bool ?? false
        self.deliverySuspensionShouldError = rawValue["deliverySuspensionShouldError"] as? Bool ?? false
        self.deliveryResumptionShouldError = rawValue["deliveryResumptionShouldError"] as? Bool ?? false
        self.maximumBolus = rawValue["maximumBolus"] as? Double ?? 25.0
        self.maximumBasalRatePerHour = rawValue["maximumBasalRatePerHour"] as? Double ?? 5.0
        self.pumpBatteryChargeRemaining = rawValue["pumpBatteryChargeRemaining"] as? Double ?? nil
        self.occlusionDetected = rawValue["occlusionDetected"] as? Bool ?? false
        self.pumpErrorDetected = rawValue["pumpErrorDetected"] as? Bool ?? false

        if let rawUnfinalizedBolus = rawValue["unfinalizedBolus"] as? UnfinalizedDose.RawValue {
            self.unfinalizedBolus = UnfinalizedDose(rawValue: rawUnfinalizedBolus)
        }

        if let rawUnfinalizedTempBasal = rawValue["unfinalizedTempBasal"] as? UnfinalizedDose.RawValue {
            self.unfinalizedTempBasal = UnfinalizedDose(rawValue: rawUnfinalizedTempBasal)
        }

        if let rawFinalizedDoses = rawValue["finalizedDoses"] as? [UnfinalizedDose.RawValue] {
            self.finalizedDoses = rawFinalizedDoses.compactMap( { UnfinalizedDose(rawValue: $0) } )
        } else {
            self.finalizedDoses = []
        }

        if let rawSuspendState = rawValue["suspendState"] as? SuspendState.RawValue, let suspendState = SuspendState(rawValue: rawSuspendState) {
            self.suspendState = suspendState
        } else {
            self.suspendState = .resumed(Date())
        }
    }

    public var rawValue: RawValue {

        var raw: RawValue = [
            "reservoirUnitsRemaining": reservoirUnitsRemaining,
        ]

        raw["suspendState"] = suspendState.rawValue

        if tempBasalEnactmentShouldError {
            raw["tempBasalEnactmentShouldError"] = true
        }

        if bolusEnactmentShouldError {
            raw["bolusEnactmentShouldError"] = true
        }

        if deliverySuspensionShouldError {
            raw["deliverySuspensionShouldError"] = true
        }

        if deliveryResumptionShouldError {
            raw["deliveryResumptionShouldError"] = true
        }

        raw["finalizedDoses"] = finalizedDoses.map( { $0.rawValue })

        raw["maximumBolus"] = maximumBolus
        raw["maximumBasalRatePerHour"] = maximumBasalRatePerHour

        raw["unfinalizedBolus"] = unfinalizedBolus?.rawValue
        raw["unfinalizedTempBasal"] = unfinalizedTempBasal?.rawValue

        raw["pumpBatteryChargeRemaining"] = pumpBatteryChargeRemaining
        
        raw["occlusionDetected"] = occlusionDetected
        raw["pumpErrorDetected"] = pumpErrorDetected

        return raw
    }
}

extension MockPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        ## MockPumpManagerState
        * reservoirUnitsRemaining: \(reservoirUnitsRemaining)
        * tempBasalEnactmentShouldError: \(tempBasalEnactmentShouldError)
        * bolusEnactmentShouldError: \(bolusEnactmentShouldError)
        * deliverySuspensionShouldError: \(deliverySuspensionShouldError)
        * deliveryResumptionShouldError: \(deliveryResumptionShouldError)
        * maximumBolus: \(maximumBolus)
        * maximumBasalRatePerHour: \(maximumBasalRatePerHour)
        * pumpBatteryChargeRemaining: \(String(describing: pumpBatteryChargeRemaining))
        * suspendState: \(suspendState)
        * unfinalizedBolus: \(String(describing: unfinalizedBolus))
        * unfinalizedTempBasal: \(String(describing: unfinalizedTempBasal))
        * finalizedDoses: \(finalizedDoses)
        * occlusionDetected: \(occlusionDetected)
        * pumpErrorDetected: \(pumpErrorDetected)
        """
    }
}

public enum SuspendState: Equatable, RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum SuspendStateType: Int {
        case suspend, resume
    }

    case suspended(Date)
    case resumed(Date)

    public init?(rawValue: RawValue) {
        guard let suspendStateType = rawValue["suspendStateType"] as? SuspendStateType.RawValue,
            let date = rawValue["date"] as? Date else {
                return nil
        }
        switch SuspendStateType(rawValue: suspendStateType) {
        case .suspend?:
            self = .suspended(date)
        case .resume?:
            self = .resumed(date)
        default:
            return nil
        }
    }

    public var rawValue: RawValue {
        switch self {
        case .suspended(let date):
            return [
                "suspendStateType": SuspendStateType.suspend.rawValue,
                "date": date
            ]
        case .resumed(let date):
            return [
                "suspendStateType": SuspendStateType.resume.rawValue,
                "date": date
            ]
        }
    }
}
