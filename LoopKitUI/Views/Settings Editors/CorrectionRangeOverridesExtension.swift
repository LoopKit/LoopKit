//
//  CorrectionRangeOverridesExtension.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/15/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit
import SwiftUI

extension CorrectionRangeOverrides.Preset {
    public func icon(usingCarbTintColor carbTintColor: Color,
                     orGlucoseTintColor glucoseTintColor: Color, resizable: Bool = false) -> some View
    {
        switch self {
        case .preMeal:
            return icon(named: "Pre-Meal", tinted: carbTintColor, resizable: resizable)
        case .workout:
            return icon(named: "workout", tinted: glucoseTintColor, resizable: resizable)
        }
    }
        
    @ViewBuilder
    private func icon(named name: String, tinted color: Color, resizable: Bool) -> some View {
        if resizable {
            Image(name)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(color)
        } else {
            Image(name)
                .renderingMode(.template)
                .foregroundColor(color)
        }
    }
}
