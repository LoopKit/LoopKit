//
//  TemporaryScheduleOverrideSettings.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


public struct TemporaryScheduleOverrideSettings: Hashable {
    public var targetRange: DoubleRange?
    public var insulinNeedsScaleFactor: Double?

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

    public init(targetRange: DoubleRange?, insulinNeedsScaleFactor: Double? = nil) {
        self.targetRange = targetRange
        self.insulinNeedsScaleFactor = insulinNeedsScaleFactor
    }
}

extension TemporaryScheduleOverrideSettings: RawRepresentable {
    public typealias RawValue = [String: Any]

    private enum Key {
        static let targetRange = "targetRange"
        static let insulinNeedsScaleFactor = "insulinNeedsScaleFactor"
    }

    public init?(rawValue: RawValue) {
        if let targetRangeRawValue = rawValue[Key.targetRange] as? DoubleRange.RawValue,
            let targetRange = DoubleRange(rawValue: targetRangeRawValue) {
            self.targetRange = targetRange
        }

        self.insulinNeedsScaleFactor = rawValue[Key.insulinNeedsScaleFactor] as? Double
    }

    public var rawValue: RawValue {
        var raw: RawValue = [:]

        if let targetRange = targetRange {
            raw[Key.targetRange] = targetRange.rawValue
        }

        if let insulinNeedsScaleFactor = insulinNeedsScaleFactor {
            raw[Key.insulinNeedsScaleFactor] = insulinNeedsScaleFactor
        }

        return raw
    }
}
