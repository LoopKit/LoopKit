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
    var icon: some View {
        switch self {
        case .preMeal:
            return icon(named: "Pre-Meal", tinted: Color(.COBTintColor))
        case .workout:
            return icon(named: "workout", tinted: Color(.glucoseTintColor))
        }
    }
    
    private func icon(named name: String, tinted color: Color) -> some View {
        Image(name)
            .renderingMode(.template)
            .foregroundColor(color)
    }
}
