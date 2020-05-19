//
//  GlucoseRangePicker.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


struct GlucoseRangePicker: View {
    @Binding var lowerBound: HKQuantity
    @Binding var upperBound: HKQuantity
    var unit: HKUnit
    var minValue: HKQuantity?
    var guardrail: Guardrail<HKQuantity>
    var stride: HKQuantity
    var formatter: NumberFormatter
    var availableWidth: CGFloat

    init(
        range: Binding<ClosedRange<HKQuantity>>,
        unit: HKUnit,
        minValue: HKQuantity?,
        guardrail: Guardrail<HKQuantity>,
        stride: HKQuantity,
        availableWidth: CGFloat
    ) {
        self._lowerBound = Binding(
            get: { range.wrappedValue.lowerBound},
            set: { range.wrappedValue = $0...range.wrappedValue.upperBound }
        )
        self._upperBound = Binding(
            get: { range.wrappedValue.upperBound },
            set: { range.wrappedValue = range.wrappedValue.lowerBound...$0 }
        )
        self.unit = unit
        self.minValue = minValue
        self.guardrail = guardrail
        self.stride = stride
        self.formatter = {
            let quantityFormatter = QuantityFormatter()
            quantityFormatter.setPreferredNumberFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
        self.availableWidth = availableWidth
    }

    var body: some View {
        HStack(spacing: 0) {
            GlucoseValuePicker(
                value: $lowerBound,
                unit: unit,
                guardrail: guardrail,
                bounds: lowerBoundRange,
                isUnitLabelVisible: false
            )
            // Ensure the selectable picker values update when either bound changes
            .id(lowerBound...upperBound)
            .frame(width: availableWidth / 3.5)
            .overlay(
                Text(separator)
                    .foregroundColor(Color(.secondaryLabel))
                    .offset(x: spacing + separatorWidth),
                alignment: .trailing
            )
            .padding(.trailing, spacing + separatorWidth + spacing)
            .clipped()

            GlucoseValuePicker(
                value: $upperBound,
                unit: unit,
                guardrail: guardrail,
                bounds: upperBoundRange
            )
            // Ensure the selectable picker values update when either bound changes
            .id(lowerBound...upperBound)
            .frame(width: availableWidth / 3.5)
            .padding(.trailing, spacing + unitLabelWidth)
            .clipped()
        }
    }

    var separator: String { "–" }

    var separatorWidth: CGFloat {
        let attributedSeparator = NSAttributedString(
            string: separator,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )

        return attributedSeparator.size().width
    }

    var spacing: CGFloat { 8 }

    var unitLabelWidth: CGFloat {
        let attributedUnitString = NSAttributedString(
            string: unit.shortLocalizedUnitString(),
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
        )

        return attributedUnitString.size().width
    }

    var lowerBoundRange: ClosedRange<HKQuantity> {
        let min = minValue.map { Swift.max(guardrail.absoluteBounds.lowerBound, $0) }
            ?? guardrail.absoluteBounds.lowerBound
        let max = Swift.min(guardrail.absoluteBounds.upperBound, upperBound)
        return min...max
    }

    var upperBoundRange: ClosedRange<HKQuantity> {
        let min = max(guardrail.absoluteBounds.lowerBound, lowerBound)
        let max = guardrail.absoluteBounds.upperBound
        return min...max
    }
}
