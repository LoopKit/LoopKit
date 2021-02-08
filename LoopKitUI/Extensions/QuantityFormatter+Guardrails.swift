//
//  QuantityFormatter+Guardrails.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 11/30/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit
import LoopKit

fileprivate let mgdLFormatter = QuantityFormatter()
fileprivate let mmolLFormatter: QuantityFormatter = {
    let result = QuantityFormatter()
    result.numberFormatter.maximumFractionDigits = 1
    return result
}()

extension HKQuantity {
    // TODO: pass in preferredUnit instead of having both units.
    var bothUnitsString: String {
        String(format: "%1$@ (%2$@)",
               mgdLFormatter.string(from: self, for: .milligramsPerDeciliter)!,
               mmolLFormatter.string(from: self, for: .millimolesPerLiter)!)
    }
}
