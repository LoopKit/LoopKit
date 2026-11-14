//
//  TemporaryScheduleOverrideSettings.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit


public struct TemporaryScheduleOverrideSettings: Hashable {
    private var targetRangeInMgdl: DoubleRange?
    public var insulinNeedsScaleFactor: Double?
    public var autoBolusCarbsActive: Bool?

    public var targetRange: ClosedRange<HKQuantity>? {
        return targetRangeInMgdl.map { $0.quantityRange(for: .milligramsPerDeciliter) }
    }

    public var basalRateMultiplier: Double? {
        return insulinNeedsScaleFactor
    }

    public var insulinSensitivityMultiplier: Double? {
        return insulinNeedsScaleFactor.map { 1.0 / $0 }
    }

    public var carbRatioMultiplier: Double? {
        return insulinNeedsScaleFactor.map { 1.0 / $0 }
    }

    public var effectiveInsulinNeedsScaleFactor: Double {
        return insulinNeedsScaleFactor ?? 1.0
    }
    
    public init() {
        self.init(targetRange: nil)
    }
    

    public init(unit: HKUnit, targetRange: DoubleRange?, insulinNeedsScaleFactor: Double? = nil, autoBolusCarbsActive: Bool? = nil) {
        self.init(targetRange: targetRange?.quantityRange(for: unit), insulinNeedsScaleFactor: insulinNeedsScaleFactor, autoBolusCarbsActive: autoBolusCarbsActive)
    }

    public init(targetRange: ClosedRange<HKQuantity>?, insulinNeedsScaleFactor: Double? = nil, autoBolusCarbsActive: Bool? = nil) {
        self.targetRangeInMgdl = targetRange?.doubleRange(for: .milligramsPerDeciliter)
        self.insulinNeedsScaleFactor = insulinNeedsScaleFactor
        self.autoBolusCarbsActive = autoBolusCarbsActive
    }
}

extension TemporaryScheduleOverrideSettings: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum Key {
        static let targetRange = "targetRange"
        static let insulinNeedsScaleFactor = "insulinNeedsScaleFactor"
        static let autoBolusCarbsActive = "autoBolusCarbsActive"
        static let version = "version"
    }

    public init?(rawValue: RawValue) {
        if let targetRangeRawValue = rawValue[Key.targetRange] as? DoubleRange.RawValue,
            let targetRange = DoubleRange(rawValue: targetRangeRawValue) {
            self.targetRangeInMgdl = targetRange
        }
        let version = rawValue[Key.version] as? Int ?? 0

        // Do not allow target ranges from versions < 1, as there was no unit convention at that point.
        if version < 1 && targetRange != nil {
            return nil
        }

        self.insulinNeedsScaleFactor = rawValue[Key.insulinNeedsScaleFactor] as? Double
        self.autoBolusCarbsActive = rawValue[Key.autoBolusCarbsActive] as? Bool
    }

    public var rawValue: RawValue {
        var raw: RawValue = [:]

        if let targetRangeInMgdl = targetRangeInMgdl {
            raw[Key.targetRange] = targetRangeInMgdl.rawValue
        }

        if let insulinNeedsScaleFactor = insulinNeedsScaleFactor {
            raw[Key.insulinNeedsScaleFactor] = insulinNeedsScaleFactor
        }
        
        if let autoBolusCarbsActive = autoBolusCarbsActive {
            raw[Key.autoBolusCarbsActive] = autoBolusCarbsActive
        }

        raw[Key.version] = 2

        return raw
    }
}

extension TemporaryScheduleOverrideSettings: Codable {}
