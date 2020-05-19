//
//  GuardrailConstrainedQuantityRangeView.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


struct GuardrailConstrainedQuantityRangeView: View {
    var range: ClosedRange<HKQuantity>
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>
    var isEditing: Bool
    var formatter: NumberFormatter

    @State var hasAppeared = false

    init(
        range: ClosedRange<HKQuantity>,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        isEditing: Bool
    ) {
        self.range = range
        self.unit = unit
        self.guardrail = guardrail
        self.isEditing = isEditing
        self.formatter = {
            let quantityFormatter = QuantityFormatter()
            quantityFormatter.setPreferredNumberFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
    }

    var body: some View {
        HStack {
            GuardrailConstrainedQuantityView(
                value: range.lowerBound,
                unit: unit,
                guardrail: guardrail,
                isEditing: isEditing,
                iconSpacing: 4,
                isUnitLabelVisible: false
            )

            Text("–")
                .foregroundColor(Color(.secondaryLabel))
                .animation(isEditing || !hasAppeared ? nil : .default)

            GuardrailConstrainedQuantityView(
                value: range.upperBound,
                unit: unit,
                guardrail: guardrail,
                isEditing: isEditing,
                iconSpacing: 4,
                iconAnimatesOut: false
            )
        }
        .onAppear { self.hasAppeared = true }
    }
}
