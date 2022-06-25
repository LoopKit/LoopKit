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


public struct GlucoseRangePicker: View {
    public enum UsageContext: Equatable {
        /// This picker is one component of a larger multi-component picker (e.g. a schedule item picker).
        case component(availableWidth: CGFloat)

        /// This picker operates independently.
        case independent
    }

    @Binding var lowerBound: HKQuantity
    @Binding var upperBound: HKQuantity
    var unit: HKUnit
    var minValue: HKQuantity?
    var maxValue: HKQuantity?
    var guardrail: Guardrail<HKQuantity>
    var formatter: NumberFormatter
    var usageContext: UsageContext

    public init(
        range: Binding<ClosedRange<HKQuantity>>,
        unit: HKUnit,
        minValue: HKQuantity?,
        maxValue: HKQuantity? = nil,
        guardrail: Guardrail<HKQuantity>,
        usageContext: UsageContext = .independent
    ) {
        self._lowerBound = Binding(
            get: { range.wrappedValue.lowerBound },
            set: {
                if $0 > range.wrappedValue.upperBound {
                    // Prevent crash if picker gets into state where "lower bound" > "upper bound"
                    range.wrappedValue = $0...$0
                }
                range.wrappedValue = $0...range.wrappedValue.upperBound
                
        }
        )
        self._upperBound = Binding(
            get: { range.wrappedValue.upperBound },
            set: {
                if range.wrappedValue.lowerBound > $0 {
                    // Prevent crash if picker gets into state where "lower bound" > "upper bound"
                    range.wrappedValue = range.wrappedValue.lowerBound...range.wrappedValue.lowerBound
                } else {
                    range.wrappedValue = range.wrappedValue.lowerBound...$0
                }
                
        }
        )
        self.unit = unit
        self.minValue = minValue
        self.maxValue = maxValue
        self.guardrail = guardrail
        self.formatter = {
            let quantityFormatter = QuantityFormatter()
            quantityFormatter.setPreferredNumberFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
        self.usageContext = usageContext
    }

    public var body: some View {
        switch usageContext {
        case .component(availableWidth: let availableWidth):
            body(availableWidth: availableWidth)
        case .independent:
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Spacer()
                    self.body(availableWidth: geometry.size.width)
                    Spacer()
                }
            }
            .frame(height: 216)
        }
    }

    private func body(availableWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            GlucoseValuePicker(
                value: $lowerBound,
                unit: unit,
                guardrail: guardrail,
                bounds: lowerBoundRange,
                isUnitLabelVisible: false
            )
            .frame(width: availableWidth / 3)
            .overlay(
                Text(separator)
                    .foregroundColor(Color(.secondaryLabel))
                    .offset(x: spacing + separatorWidth),
                alignment: .trailing
            )
            .padding(.leading, usageContext == .independent ? unitLabelWidth : 0)
            .padding(.trailing, spacing + separatorWidth + spacing)
            .clipped()
            .compositingGroup()
            .accessibility(identifier: "min_glucose_picker")

            GlucoseValuePicker(
                value: $upperBound,
                unit: unit,
                guardrail: guardrail,
                bounds: upperBoundRange
            )
            .frame(width: availableWidth / 3)
            .padding(.trailing, unitLabelWidth)
            .clipped()
            .compositingGroup()
            .accessibility(identifier: "max_glucose_picker")
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

    var spacing: CGFloat { 4 }

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
        let max = maxValue.map { Swift.min(guardrail.absoluteBounds.upperBound, $0) }
            ?? guardrail.absoluteBounds.upperBound
        return min...max
    }
}
