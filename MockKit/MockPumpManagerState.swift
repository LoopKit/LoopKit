//
//  MockPumpManagerState.swift
//  MockKit
//
//  Created by Pete Schwamb on 7/31/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

public struct MockPumpManagerState {
    public enum DeliverableIncrements: String, CaseIterable {
        case omnipod
        case medtronicX22
        case medtronicX23
        case custom
        
        var supportedBolusVolumes: [Double]? {
            switch self {
            case .omnipod:
                // 0.05 units for volumes between 0.05-30U
                return (1...600).map { Double($0) * 0.05 }
            case .medtronicX22:
                // 0.1 units for volumes between 0.1-25U
                return (1...250).map { Double($0) * 0.1 }
            case .medtronicX23:
                let breakpoints = [0, 1, 10, 25]
                let scales = [40, 20, 10]
                let scalingGroups = zip(scales, breakpoints.adjacentPairs().map(...))
                return scalingGroups.flatMap { (scale, range) -> [Double] in
                    let scaledRanges = (range.lowerBound * scale + 1)...(range.upperBound * scale)
                    return scaledRanges.map { Double($0) / Double(scale) }
                }
            case .custom:
                return nil
            }
        }
        
        var bolusVolumesDescription: String? {
            switch self {
            case .omnipod:
                // 0.05 units for volumes between 0.05-30U
                return "0.05-30 by 0.05"
            case .medtronicX22:
                // 0.1 units for volumes between 0.1-25U
                return "0.1-25 by 0.1"
            case .medtronicX23:
                // 0.025 units for rates between 0.0-0.975 U/h
                // 0.05 units for rates between 1-9.95 U/h
                // 0.1 units for rates between 10-25 U/h
                return "0-1-10-25 by 0.025|0.05|0.1"
            case .custom:
                return nil
            }
        }
        
        var supportedBasalRates: [Double]? {
            switch self {
            case .omnipod:
                // 0.05 units for rates between 0.05-30U/hr
                return (1...600).map { Double($0) / 20 }
            case .medtronicX22:
                // 0.05 units for rates between 0.0-35U/hr
                return (0...700).map { Double($0) / 20 }
            case .medtronicX23:
                // 0.025 units for rates between 0.0-0.975 U/h
                let rateGroup1 = (0...39).map { Double($0) / 40 }
                // 0.05 units for rates between 1-9.95 U/h
                let rateGroup2 = (20...199).map { Double($0) / 20 }
                // 0.1 units for rates between 10-35 U/h
                let rateGroup3 = (100...350).map { Double($0) / 10 }
                return rateGroup1 + rateGroup2 + rateGroup3
            case .custom:
                return nil
            }
        }
        
        public var basalRateDescription: String? {
            switch self {
            case .omnipod:
                // 0.05 units for rates between 0.05-30U/hr
                return "0.05-30 by 0.05"
            case .medtronicX22:
                // 0.05 units for rates between 0.0-35U/hr
                return "0-35 by 0.05"
            case .medtronicX23:
                // 0.025 units for rates between 0.0-0.975 U/h
                // 0.05 units for rates between 1-9.95 U/h
                // 0.1 units for rates between 10-35 U/h
                return "0-1-10-35 by 0.025|0.05|0.1"
            case .custom:
                return nil
            }
        }
    }

    public var deliverableIncrements: DeliverableIncrements {
        didSet {
            if let supportedBasalRates = deliverableIncrements.supportedBasalRates {
                self.supportedBasalRates = supportedBasalRates
            } else if let minBasalRates = supportedBasalRates.first, let maxBasalRates = supportedBasalRates.last, supportedBasalRates.indices.contains(1) {
                let stepSize = supportedBasalRates[1]-minBasalRates
                self.supportedBasalRates = (Int(minBasalRates/stepSize)...Int(maxBasalRates/stepSize)).map { Double($0) / (1 / stepSize) }
            }

            if let supportedBolusVolumes = deliverableIncrements.supportedBolusVolumes {
                self.supportedBolusVolumes = supportedBolusVolumes
            } else if let minBolusVolumes = supportedBolusVolumes.first, let maxBolusVolumes = supportedBolusVolumes.last, supportedBolusVolumes.indices.contains(1) {
                let stepSize = supportedBolusVolumes[1]-minBolusVolumes
                self.supportedBolusVolumes = (Int(minBolusVolumes/stepSize)...Int(maxBolusVolumes/stepSize)).map { Double($0) / (1 / stepSize) }
            }
        }
    }
    
    public var supportedBolusVolumes: [Double]
    public var supportedBolusVolumesDescription: String {
        guard let bolusVolumesDescription = deliverableIncrements.bolusVolumesDescription else {
            guard let minBolusVolume = supportedBolusVolumes.first, let maxBolusVolume = supportedBolusVolumes.last, supportedBolusVolumes.indices.contains(1) else {
                return "–"
            }
            return String(format: "\(minBolusVolume)-\(maxBolusVolume) by %.3f", (supportedBolusVolumes[1]-minBolusVolume))
        }
        return bolusVolumesDescription
    }
    
    public var supportedBasalRates: [Double]
    public var supportedBasalRatesDescription: String {
        guard let basalRatesDescription = deliverableIncrements.basalRateDescription else {
            guard let minBasalRate = supportedBasalRates.first, let maxBasalRate = supportedBasalRates.last, supportedBasalRates.indices.contains(1) else {
                return "–"
            }
            return String(format: "\(minBasalRate)-\(maxBasalRate) by %.3f", (supportedBasalRates[1]-minBasalRate))
        }
        return basalRatesDescription
    }

    public var basalRateSchedule: BasalRateSchedule?
    public var reservoirUnitsRemaining: Double
    public var tempBasalEnactmentShouldError: Bool
    public var bolusEnactmentShouldError: Bool
    public var bolusCancelShouldError: Bool
    public var deliverySuspensionShouldError: Bool
    public var deliveryResumptionShouldError: Bool
    public var deliveryCommandsShouldTriggerUncertainDelivery: Bool
    public var maximumBolus: Double
    public var maximumBasalRatePerHour: Double
    public var suspendState: SuspendState
    public var pumpBatteryChargeRemaining: Double?
    public var occlusionDetected: Bool = false
    public var pumpErrorDetected: Bool = false
    public var deliveryIsUncertain: Bool = false

    public var unfinalizedBolus: UnfinalizedDose?
    public var unfinalizedTempBasal: UnfinalizedDose?
    
    var finalizedDoses: [UnfinalizedDose]

    public var progressPercentComplete: Double?
    public var progressWarningThresholdPercentValue: Double?
    public var progressCriticalThresholdPercentValue: Double?
    
    public var insulinType: InsulinType
    public var timeZone: TimeZone
    
    public var dosesToStore: [UnfinalizedDose] {
        return finalizedDoses + [unfinalizedTempBasal, unfinalizedBolus].compactMap {$0}
    }

    public init(deliverableIncrements: DeliverableIncrements = .medtronicX22,
                reservoirUnitsRemaining: Double = 200.0,
                tempBasalEnactmentShouldError: Bool = false,
                bolusEnactmentShouldError: Bool = false,
                bolusCancelShouldError: Bool = false,
                deliverySuspensionShouldError: Bool = false,
                deliveryResumptionShouldError: Bool = false,
                deliveryCommandsShouldTriggerUncertainDelivery: Bool = false,
                maximumBolus: Double = 25.0,
                maximumBasalRatePerHour: Double = 5.0,
                suspendState: SuspendState = .resumed(Date()),
                pumpBatteryChargeRemaining: Double? = 1,
                unfinalizedBolus: UnfinalizedDose? = nil,
                unfinalizedTempBasal: UnfinalizedDose? = nil,
                finalizedDoses: [UnfinalizedDose] = [],
                progressWarningThresholdPercentValue: Double? = 0.75,
                progressCriticalThresholdPercentValue: Double? = 0.9,
                insulinType: InsulinType = .novolog)
    {
        self.deliverableIncrements = deliverableIncrements
        self.supportedBolusVolumes = deliverableIncrements.supportedBolusVolumes ?? []
        self.supportedBasalRates = deliverableIncrements.supportedBasalRates ?? []
        self.reservoirUnitsRemaining = reservoirUnitsRemaining
        self.tempBasalEnactmentShouldError = tempBasalEnactmentShouldError
        self.bolusEnactmentShouldError = bolusEnactmentShouldError
        self.bolusCancelShouldError = bolusCancelShouldError
        self.deliverySuspensionShouldError = deliverySuspensionShouldError
        self.deliveryResumptionShouldError = deliveryResumptionShouldError
        self.deliveryCommandsShouldTriggerUncertainDelivery = deliveryCommandsShouldTriggerUncertainDelivery
        self.maximumBolus = maximumBolus
        self.maximumBasalRatePerHour = maximumBasalRatePerHour
        self.suspendState = suspendState
        self.pumpBatteryChargeRemaining = pumpBatteryChargeRemaining
        self.finalizedDoses = finalizedDoses
        self.progressWarningThresholdPercentValue = progressWarningThresholdPercentValue
        self.progressCriticalThresholdPercentValue = progressCriticalThresholdPercentValue
        self.insulinType = insulinType
        self.timeZone = .currentFixed
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

        let defaultDeliverableIncrements: DeliverableIncrements = .medtronicX22
        self.deliverableIncrements = (rawValue["deliverableIncrements"] as? DeliverableIncrements.RawValue).flatMap(DeliverableIncrements.init(rawValue:)) ?? defaultDeliverableIncrements
        self.supportedBolusVolumes = rawValue["supportedBolusVolumes"] as? [Double] ?? defaultDeliverableIncrements.supportedBolusVolumes ?? []
        self.supportedBasalRates = rawValue["supportedBasalRates"] as? [Double] ?? defaultDeliverableIncrements.supportedBasalRates ?? []
        self.reservoirUnitsRemaining = reservoirUnitsRemaining
        self.tempBasalEnactmentShouldError = rawValue["tempBasalEnactmentShouldError"] as? Bool ?? false
        self.bolusEnactmentShouldError = rawValue["bolusEnactmentShouldError"] as? Bool ?? false
        self.bolusCancelShouldError = rawValue["bolusCancelShouldError"] as? Bool ?? false
        self.deliverySuspensionShouldError = rawValue["deliverySuspensionShouldError"] as? Bool ?? false
        self.deliveryResumptionShouldError = rawValue["deliveryResumptionShouldError"] as? Bool ?? false
        self.deliveryCommandsShouldTriggerUncertainDelivery = rawValue["deliveryCommandsShouldTriggerUncertainDelivery"] as? Bool ?? false
        self.maximumBolus = rawValue["maximumBolus"] as? Double ?? 25.0
        self.maximumBasalRatePerHour = rawValue["maximumBasalRatePerHour"] as? Double ?? 5.0
        self.pumpBatteryChargeRemaining = rawValue["pumpBatteryChargeRemaining"] as? Double ?? nil
        self.occlusionDetected = rawValue["occlusionDetected"] as? Bool ?? false
        self.pumpErrorDetected = rawValue["pumpErrorDetected"] as? Bool ?? false
        self.deliveryIsUncertain = rawValue["deliveryIsUncertain"] as? Bool ?? false

        self.progressPercentComplete = rawValue["progressPercentComplete"] as? Double
        self.progressWarningThresholdPercentValue = rawValue["progressWarningThresholdPercentValue"] as? Double
        self.progressCriticalThresholdPercentValue = rawValue["progressCriticalThresholdPercentValue"] as? Double

        if let rawBasalRateSchedule = rawValue["basalRateSchedule"] as? BasalRateSchedule.RawValue {
            self.basalRateSchedule = BasalRateSchedule(rawValue: rawBasalRateSchedule)
        }

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
        
        if let rawInsulinType = rawValue["insulinType"] as? InsulinType.RawValue, let insulinType = InsulinType(rawValue: rawInsulinType) {
            self.insulinType = insulinType
        } else {
            self.insulinType = .novolog
        }

        if let timeZoneOffset = rawValue["timeZone"] as? Int {
            self.timeZone = TimeZone(secondsFromGMT: timeZoneOffset) ?? .currentFixed
        } else {
            self.timeZone = .currentFixed
        }
    }

    public var rawValue: RawValue {

        var raw: RawValue = [
            "deliverableIncrements": deliverableIncrements.rawValue,
            "supportedBolusVolumes": supportedBolusVolumes,
            "supportedBasalRates": supportedBasalRates,
            "reservoirUnitsRemaining": reservoirUnitsRemaining,
            "insulinType": insulinType.rawValue,
            "timeZone": timeZone.secondsFromGMT()
        ]

        raw["basalRateSchedule"] = basalRateSchedule?.rawValue
        raw["suspendState"] = suspendState.rawValue

        if tempBasalEnactmentShouldError {
            raw["tempBasalEnactmentShouldError"] = true
        }

        if bolusEnactmentShouldError {
            raw["bolusEnactmentShouldError"] = true
        }

        if bolusCancelShouldError {
            raw["bolusCancelShouldError"] = true
        }

        if deliverySuspensionShouldError {
            raw["deliverySuspensionShouldError"] = true
        }

        if deliveryResumptionShouldError {
            raw["deliveryResumptionShouldError"] = true
        }
        
        if deliveryCommandsShouldTriggerUncertainDelivery {
            raw["deliveryCommandsShouldTriggerUncertainDelivery"] = true
        }

        if deliveryIsUncertain {
            raw["deliveryIsUncertain"] = true
        }

        raw["finalizedDoses"] = finalizedDoses.map( { $0.rawValue })

        raw["maximumBolus"] = maximumBolus
        raw["maximumBasalRatePerHour"] = maximumBasalRatePerHour

        raw["unfinalizedBolus"] = unfinalizedBolus?.rawValue
        raw["unfinalizedTempBasal"] = unfinalizedTempBasal?.rawValue

        raw["pumpBatteryChargeRemaining"] = pumpBatteryChargeRemaining
        
        raw["occlusionDetected"] = occlusionDetected
        raw["pumpErrorDetected"] = pumpErrorDetected
        
        raw["progressPercentComplete"] = progressPercentComplete
        raw["progressWarningThresholdPercentValue"] = progressWarningThresholdPercentValue
        raw["progressCriticalThresholdPercentValue"] = progressCriticalThresholdPercentValue
        
        return raw
    }
}

extension MockPumpManagerState: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
        ## MockPumpManagerState
        * deliverableIncrements: \(deliverableIncrements)
        * reservoirUnitsRemaining: \(reservoirUnitsRemaining)
        * basalRateSchedule: \(basalRateSchedule as Any)
        * tempBasalEnactmentShouldError: \(tempBasalEnactmentShouldError)
        * bolusEnactmentShouldError: \(bolusEnactmentShouldError)
        * bolusCancelShouldError: \(bolusCancelShouldError)
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
        * progressPercentComplete: \(progressPercentComplete as Any)
        * progressWarningThresholdPercentValue: \(progressWarningThresholdPercentValue as Any)
        * progressCriticalThresholdPercentValue: \(progressCriticalThresholdPercentValue as Any)
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
