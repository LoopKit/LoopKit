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
import LoopAlgorithm

public struct GlucoseRangePicker: View {
    public enum UsageContext: Equatable {
        /// This picker is one component of a larger multi-component picker (e.g. a schedule item picker).
        case component(availableWidth: CGFloat)

        /// This picker operates independently.
        case independent
    }

    @Binding var lowerBound: LoopQuantity
    @Binding var upperBound: LoopQuantity
    var unit: LoopUnit
    var minValue: LoopQuantity?
    var maxValue: LoopQuantity?
    var guardrail: Guardrail<LoopQuantity>
    var formatter: NumberFormatter
    var usageContext: UsageContext

    public init(
        range: Binding<ClosedRange<LoopQuantity>>,
        unit: LoopUnit,
        minValue: LoopQuantity?,
        maxValue: LoopQuantity? = nil,
        guardrail: Guardrail<LoopQuantity>,
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
            let quantityFormatter = QuantityFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
        self.usageContext = usageContext
    }

    public var body: some View {
        switch usageContext {
        case .component(availableWidth: let availableWidth):
            body(availableWidth: availableWidth)
                .frame(height: 216)
        case .independent:
            centeredBody
                .frame(height: 216)
        }
    }

    private var centeredBody: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    lowerBoundPicker
                        .frame(width: geometry.size.width / 3)

                    Text(separator)
                        .foregroundColor(Color(.secondaryLabel))

                    upperBoundPicker
                        .frame(width: geometry.size.width / 3)
                }
                Spacer()
            }
        }
    }

    private func body(availableWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            lowerBoundPicker
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

            upperBoundPicker
                .frame(width: availableWidth / 3)
                .padding(.trailing, unitLabelWidth)
                .clipped()
                .compositingGroup()
                .accessibility(identifier: "max_glucose_picker")
        }
    }

    private var stride: Double {
        switch unit {
        case .milligramsPerDeciliter:
            return 5
        case .millimolesPerLiter:
            return 0.1
        default:
            fatalError("Unsupported glucose unit \(unit)")
        }
    }

    private var lowerBoundPicker: some View {
        GlucoseValuePicker(
            value: $lowerBound,
            unit: unit,
            guardrail: guardrail,
            selectableValues: lowerBoundRange.selectableValues(unit: unit, stride: stride),
            isUnitLabelVisible: false
        )
        .accessibility(identifier: "min_glucose_picker")
    }

    private var upperBoundPicker: some View {
        GlucoseValuePicker(
            value: $upperBound,
            unit: unit,
            guardrail: guardrail,
            selectableValues: upperBoundRange.selectableValues(unit: unit, stride: stride)
        )
        .accessibility(identifier: "max_glucose_picker")
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

    var lowerBoundRange: ClosedRange<LoopQuantity> {
        let min = minValue.map { Swift.max(guardrail.absoluteBounds.lowerBound, $0) }
            ?? guardrail.absoluteBounds.lowerBound
        let max = Swift.min(guardrail.absoluteBounds.upperBound, upperBound)
        return min...max
    }

    var upperBoundRange: ClosedRange<LoopQuantity> {
        let min = max(guardrail.absoluteBounds.lowerBound, lowerBound)
        let max = maxValue.map { Swift.min(guardrail.absoluteBounds.upperBound, $0) }
            ?? guardrail.absoluteBounds.upperBound
        return min...max
    }
}
