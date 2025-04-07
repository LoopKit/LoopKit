//
//  DisplayGlucosePreference.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-10.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopAlgorithm
import SwiftUI
import LoopKit

public class DisplayGlucosePreference: ObservableObject {
    @Published public private(set) var unit: LoopUnit
    @Published public private(set) var formatter: QuantityFormatter

    public init(displayGlucoseUnit: LoopUnit) {
        self.unit = displayGlucoseUnit
        let formatter = QuantityFormatter(for: displayGlucoseUnit)
        self.formatter = formatter
        self.formatter.numberFormatter.notANumberSymbol = "–"
    }

    /// Formats a glucose HKQuantity and unit as a localized string
    ///
    /// - Parameters:
    ///   - quantity: The quantity
    ///   - includeUnit: Whether or not to include the unit in the returned string
    /// - Returns: A localized string, or the numberFormatter's notANumberSymbol (default is "–")
    open func format(_ quantity: LoopQuantity, includeUnit: Bool = true) -> String {
        return formatter.string(from: quantity, includeUnit: includeUnit) ?? self.formatter.numberFormatter.notANumberSymbol
    }
    
    open func format(lowerQuantity: LoopQuantity, higherQuantity: LoopQuantity, includeUnit: Bool = true) -> String {
        guard let lower = formatter.string(from: lowerQuantity, includeUnit: false), let higher = formatter.string(from: higherQuantity, includeUnit: includeUnit) else {
            return self.formatter.numberFormatter.notANumberSymbol
        }
        
        return "\(lower)-\(higher)"
    }

    /// Formats a glucose HKQuantity rate (in terms of mg/dL/min or mmol/L/min and unit as a localized string
    ///
    /// - Parameters:
    ///   - quantity: The quantity
    ///   - includeUnit: Whether or not to include the unit in the returned string
    /// - Returns: A localized string, or the numberFormatter's notANumberSymbol (default is "–")
    open func formatMinuteRate(_ quantity: LoopQuantity, includeUnit: Bool = true) -> String {
        let minuteRateFormatter = QuantityFormatter(for: unit.unitDivided(by: .minute))
        return  minuteRateFormatter.string(from: quantity, includeUnit: includeUnit) ?? formatter.numberFormatter.notANumberSymbol
    }

}

extension DisplayGlucosePreference: DisplayGlucoseUnitObserver {
    public func unitDidChange(to displayGlucoseUnit: LoopUnit) {
        self.unit = displayGlucoseUnit
        let formatter = QuantityFormatter(for: displayGlucoseUnit)
        self.formatter = formatter
    }
}
