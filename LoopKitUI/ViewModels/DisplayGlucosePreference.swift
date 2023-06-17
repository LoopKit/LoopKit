//
//  DisplayGlucosePreference.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-10.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import SwiftUI
import LoopKit

public class DisplayGlucosePreference: ObservableObject {
    @Published public private(set) var unit: HKUnit
    @Published public private(set) var rateUnit: HKUnit
    @Published public private(set) var formatter: QuantityFormatter
    @Published public private(set) var minuteRateFormatter: QuantityFormatter

    public init(displayGlucoseUnit: HKUnit) {
        let rateUnit = displayGlucoseUnit.unitDivided(by: .minute())

        self.unit = displayGlucoseUnit
        self.rateUnit = rateUnit
        self.formatter = QuantityFormatter(for: displayGlucoseUnit)
        self.minuteRateFormatter = QuantityFormatter(for: rateUnit)
        self.formatter.numberFormatter.notANumberSymbol = "–"
        self.minuteRateFormatter.numberFormatter.notANumberSymbol = "–"
    }

    /// Formats a glucose HKQuantity and unit as a localized string
    ///
    /// - Parameters:
    ///   - quantity: The quantity
    ///   - includeUnit: Whether or not to include the unit in the returned string
    /// - Returns: A localized string, or the numberFormatter's notANumberSymbol (default is "–")
    open func format(_ quantity: HKQuantity, includeUnit: Bool = true) -> String {
        return formatter.string(from: quantity, includeUnit: includeUnit) ?? self.formatter.numberFormatter.notANumberSymbol
    }

    /// Formats a glucose HKQuantity rate (in terms of mg/dL/min or mmol/L/min and unit as a localized string
    ///
    /// - Parameters:
    ///   - quantity: The quantity
    ///   - includeUnit: Whether or not to include the unit in the returned string
    /// - Returns: A localized string, or the numberFormatter's notANumberSymbol (default is "–")
    open func formatMinuteRate(_ quantity: HKQuantity, includeUnit: Bool = true) -> String {
        return minuteRateFormatter.string(from: quantity, includeUnit: includeUnit) ?? self.formatter.numberFormatter.notANumberSymbol
    }

}

extension DisplayGlucosePreference: DisplayGlucoseUnitObserver {
    public func unitDidChange(to displayGlucoseUnit: HKUnit) {
        self.unit = displayGlucoseUnit
        self.formatter = QuantityFormatter(for: displayGlucoseUnit)
    }
}
