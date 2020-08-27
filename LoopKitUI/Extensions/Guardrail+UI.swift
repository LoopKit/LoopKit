//
//  Guardrail+UI.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


extension Guardrail where Value == HKQuantity {
    func color(for quantity: HKQuantity,
               guidanceColors: GuidanceColors) -> Color
    {
        switch classification(for: quantity) {
        case .withinRecommendedRange:
            return guidanceColors.acceptable
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return guidanceColors.critical
            case .belowRecommended, .aboveRecommended:
                return guidanceColors.warning
            }
        }
    }
}
