//
//  QuantityPicker.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


private struct PickerValueBoundsKey: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []

    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

public struct QuantityPicker: View {
    @Binding var value: HKQuantity
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>

    private let possibleValues: [Double]
    private let formatter: NumberFormatter

    public init(value: Binding<HKQuantity>, unit: HKUnit, stride: HKQuantity, guardrail: Guardrail<HKQuantity>) {
        self._value = value
        self.unit = unit
        self.guardrail = guardrail

        self.possibleValues = guardrail.allValues(stridingBy: stride, unit: unit).map { $0.doubleValue(for: unit) }
        self.formatter = {
            let quantityFormatter = QuantityFormatter()
            quantityFormatter.setPreferredNumberFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
    }

    private var selection: Binding<Double> {
        Binding(
            get: { self.value.doubleValue(for: self.unit) },
            set: { self.value = HKQuantity(unit: self.unit, doubleValue: $0) }
        )
    }

    public var body: some View {
        Picker("Quantity", selection: selection) {
            ForEach(possibleValues, id: \.self) { value in
                Text(self.formatter.string(from: value) ?? "\(value)")
                    .foregroundColor(self.pickerTextColor(for: value))
                    .anchorPreference(key: PickerValueBoundsKey.self, value: .bounds, transform: { [$0] })
            }
        }
        .labelsHidden()
        .pickerStyle(WheelPickerStyle())
        .overlayPreferenceValue(PickerValueBoundsKey.self, unitLabel(positionedFrom:))
    }

    private func pickerTextColor(for value: Double) -> Color {
        let quantity = HKQuantity(unit: unit, doubleValue: value)
        switch guardrail.classification(for: quantity) {
        case .withinRecommendedRange:
            return .primary
        case .outsideRecommendedRange(let threshold):
            switch threshold {
                case .minimum, .maximum:
                    return .severeWarning
                case .belowRecommended, .aboveRecommended:
                    return .warning
            }
        }
    }

    private func unitLabel(positionedFrom pickerValueBounds: [Anchor<CGRect>]) -> some View {
        let unitLabelOffset: CGFloat = 8
        return GeometryReader { geometry in
            if !pickerValueBounds.isEmpty {
                Text(self.unit.shortLocalizedUnitString())
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .offset(x: self.maxBounds(from: pickerValueBounds, in: geometry).maxX + unitLabelOffset)
                    .animation(.default)
            }
        }
    }

    private func maxBounds(from individualBounds: [Anchor<CGRect>], in geometry: GeometryProxy) -> CGRect {
        individualBounds.lazy
            .map { geometry[$0] }
            .reduce(.null) { $0.union($1) }
    }
}
