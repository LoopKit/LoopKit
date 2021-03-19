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
    var isUnitLabelVisible: Bool
    var colorForValue: (_ value: Double) -> Color

    private let selectableValues: [Double]
    private let formatter: NumberFormatter

    public init(
        value: Binding<HKQuantity>,
        unit: HKUnit,
        stride: HKQuantity,
        guardrail: Guardrail<HKQuantity>,
        formatter: NumberFormatter? = nil,
        isUnitLabelVisible: Bool = true,
        guidanceColors: GuidanceColors = GuidanceColors()
    ) {
        let selectableValues = guardrail.allValues(stridingBy: stride, unit: unit)
        self.init(value: value,
                  unit: unit,
                  guardrail: guardrail,
                  selectableValues: selectableValues,
                  formatter: formatter,
                  isUnitLabelVisible: isUnitLabelVisible,
                  guidanceColors: guidanceColors)
    }

    public init(
        value: Binding<HKQuantity>,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        selectableValues: [Double],
        formatter: NumberFormatter? = nil,
        isUnitLabelVisible: Bool = true,
        guidanceColors: GuidanceColors
    ) {
        self.init(
            value: value,
            unit: unit,
            selectableValues: selectableValues.map { unit.roundForPicker(value: $0) },
            formatter: formatter,
            isUnitLabelVisible: isUnitLabelVisible,
            colorForValue: { value in
                let quantity = HKQuantity(unit: unit, doubleValue: value)
                return guardrail.color(for: quantity, guidanceColors: guidanceColors)
            }
        )
    }

    public init(
        value: Binding<HKQuantity>,
        unit: HKUnit,
        selectableValues: [Double],
        formatter: NumberFormatter? = nil,
        isUnitLabelVisible: Bool = true,
        colorForValue: @escaping (_ value: Double) -> Color = { _ in .primary }
    ) {
        self._value = value
        self.unit = unit
        self.selectableValues = selectableValues
        self.formatter = formatter ?? {
            let quantityFormatter = QuantityFormatter()
            quantityFormatter.setPreferredNumberFormatter(for: unit)
            return quantityFormatter.numberFormatter
        }()
        self.isUnitLabelVisible = isUnitLabelVisible
        self.colorForValue = colorForValue
    }

    private var selectedValue: Binding<Double> {
        Binding(
            get: {
                unit.roundForPicker(value: value.doubleValue(for: unit))
            },
            set: { newValue in
                self.value = HKQuantity(unit: unit, doubleValue: newValue)
            }
        )
    }

    public var body: some View {
        Picker("Quantity", selection: selectedValue) {
            ForEach(selectableValues, id: \.self) { value in
                Text(self.formatter.string(from: value) ?? "\(value)")
                    .foregroundColor(self.colorForValue(value))
                    .anchorPreference(key: PickerValueBoundsKey.self, value: .bounds, transform: { [$0] })
                    .accessibility(identifier: self.formatter.string(from: value) ?? "\(value)")
            }
        }
        .labelsHidden()
        .pickerStyle(WheelPickerStyle())
        .overlayPreferenceValue(PickerValueBoundsKey.self, unitLabel(positionedFrom:))
        .accessibility(identifier: "quantity_picker")
    }

    private func unitLabel(positionedFrom pickerValueBounds: [Anchor<CGRect>]) -> some View {
        GeometryReader { geometry in
            if self.isUnitLabelVisible && !pickerValueBounds.isEmpty {
                Text(self.unit.shortLocalizedUnitString())
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .offset(x: pickerValueBounds.union(in: geometry).maxX + self.unitLabelSpacing)
                    .animation(.default)
            }
        }
    }

    private var unitLabelSpacing: CGFloat { 8 }
}

extension Sequence where Element == Anchor<CGRect> {
    func union(in geometry: GeometryProxy) -> CGRect {
        lazy
            .map { geometry[$0] }
            .reduce(.null) { $0.union($1) }
    }
}
