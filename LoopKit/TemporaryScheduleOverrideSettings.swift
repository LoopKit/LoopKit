//
//  TemporaryScheduleOverrideSettings.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation


public struct TemporaryScheduleOverrideSettings: Equatable {
    public var targetRange: DoubleRange
    public var basalRateMultiplier: Double?
    public var insulinSensitivityMultiplier: Double?
    public var carbRatioMultiplier: Double?

    public init(
        targetRange: DoubleRange,
        basalRateMultiplier: Double? = nil,
        insulinSensitivityMultiplier: Double? = nil,
        carbRatioMultiplier: Double? = nil
    ) {
        self.targetRange = targetRange
        self.basalRateMultiplier = basalRateMultiplier
        self.insulinSensitivityMultiplier = insulinSensitivityMultiplier
        self.carbRatioMultiplier = carbRatioMultiplier
    }

    public init(targetRange: DoubleRange, overallSensitivityFactor: Double) {
        self.init(
            targetRange: targetRange,
            basalRateMultiplier: 1 / overallSensitivityFactor,
            insulinSensitivityMultiplier: overallSensitivityFactor,
            carbRatioMultiplier: overallSensitivityFactor
        )
    }
}

extension TemporaryScheduleOverrideSettings: RawRepresentable {
    public typealias RawValue = [String: Any]

    public init?(rawValue: RawValue) {
        guard
            let targetRangeRawValue = rawValue["targetRange"] as? DoubleRange.RawValue,
            let targetRange = DoubleRange(rawValue: targetRangeRawValue)
        else {
            return nil
        }

        self.targetRange = targetRange
        self.basalRateMultiplier = rawValue["basalRateMultiplier"] as? Double
        self.insulinSensitivityMultiplier = rawValue["insulinSensitivityMultiplier"] as? Double
        self.carbRatioMultiplier = rawValue["carbRatioMultiplier"] as? Double
    }

    public var rawValue: RawValue {
        var raw: RawValue = ["targetRange": targetRange.rawValue]

        if let basalRateMultiplier = basalRateMultiplier {
            raw["basalRateMultiplier"] = basalRateMultiplier
        }

        if let insulinSensitivityMultiplier = insulinSensitivityMultiplier {
            raw["insulinSensitivityMultiplier"] = insulinSensitivityMultiplier
        }

        if let carbRatioMultiplier = carbRatioMultiplier {
            raw["carbRatioMultiplier"] = carbRatioMultiplier
        }

        return raw
    }
}
