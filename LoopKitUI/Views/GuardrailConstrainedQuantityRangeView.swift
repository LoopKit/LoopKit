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


public struct GuardrailConstrainedQuantityRangeView: View {
    var range: ClosedRange<HKQuantity>?
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>
    var isEditing: Bool
    var formatter: NumberFormatter
    var forceDisableAnimations: Bool

    @State var hasAppeared = false

    public init(
        range: ClosedRange<HKQuantity>?,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        isEditing: Bool,
        forceDisableAnimations: Bool = false
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
        self.forceDisableAnimations = forceDisableAnimations
    }

    public var body: some View {
        HStack {
            lowerBoundView

            Text("–")
                .foregroundColor(Color(.secondaryLabel))

            upperBoundView
        }
        .animation(forceDisableAnimations || isEditing || !hasAppeared ? nil : .default)
        .onAppear { self.hasAppeared = true }
    }

    var lowerBoundView: some View {
        Group {
            if range != nil {
                GuardrailConstrainedQuantityView(
                    value: range!.lowerBound,
                    unit: unit,
                    guardrail: guardrail,
                    isEditing: isEditing,
                    iconSpacing: 4,
                    isUnitLabelVisible: false,
                    forceDisableAnimations: forceDisableAnimations
                )
            } else {
                Text(LocalizedString("min", comment: "Placeholder for quantity range lower bound"))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
    }

    var upperBoundView: some View {
        Group {
            if range != nil {
                GuardrailConstrainedQuantityView(
                    value: range!.upperBound,
                    unit: unit,
                    guardrail: guardrail,
                    isEditing: isEditing,
                    iconSpacing: 4,
                    forceDisableAnimations: forceDisableAnimations
                )
            } else {
                HStack {
                    Text(LocalizedString("max", comment: "Placeholder for quantity range upper bound"))
                        .foregroundColor(Color(.tertiaryLabel))

                    Text(unit.shortLocalizedUnitString())
                        .foregroundColor(Color(.secondaryLabel))
                }
            }
        }
    }
}
