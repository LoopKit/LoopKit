//
//  Guardrail+UI.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 7/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm
import LoopKit


extension Guardrail where Value == LoopQuantity {
    public func color(for quantity: LoopQuantity, guidanceColors: GuidanceColors) -> Color {
        switch classification(for: quantity) {
        case .withinRecommendedRange:
            return guidanceColors.acceptable
        case .outsideRecommendedRange(let threshold):
            switch threshold {
            case .minimum, .maximum:
                return guidanceColors.critical
            case .belowWarning, .aboveWarning:
                return guidanceColors.critical
            case .belowRecommended, .aboveRecommended:
                return guidanceColors.warning
            }
        }
    }
}
