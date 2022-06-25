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

    private let unitLabelSpacing: CGFloat = -6
    
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
        picker
            .labelsHidden()
            .pickerStyle(.wheel)
            .overlayPreferenceValue(PickerValueBoundsKey.self, unitLabel(positionedFrom:))
            .accessibility(identifier: "quantity_picker")
    }

    @ViewBuilder
    private var picker: some View {
        // NOTE: iOS 15.1 introduced an issue where SwiftUI Pickers would not obey the `.clipped()`
        // directive when it comes to touchable area.  I have submitted a bug (Feedback) to Apple (FB9788944).
        // This uses a custom Picker that works around the issue, but not perfectly (it isn't a 1 to 1 match).
        // If they ever do fix this, consider restoring the code from the commit prior to this change.
        // See LOOP-3870 for more details.
        ResizeablePicker(selection: selectedValue,
                         data: selectableValues,
                         formatter: { self.formatter.string(from: $0) ?? "\($0)" },
                         colorer: colorForValue)
            .anchorPreference(key: PickerValueBoundsKey.self, value: .bounds, transform: { [$0] })
    }
    
    private func unitLabel(positionedFrom pickerValueBounds: [Anchor<CGRect>]) -> some View {
        GeometryReader { geometry in
            if self.isUnitLabelVisible && !pickerValueBounds.isEmpty {
                Text(self.unit.shortLocalizedUnitString())
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .offset(x: pickerValueBounds.union(in: geometry).maxX + unitLabelSpacing)
                    .animation(.default)
            }
        }
    }
}

extension Sequence where Element == Anchor<CGRect> {
    func union(in geometry: GeometryProxy) -> CGRect {
        lazy
            .map { geometry[$0] }
            .reduce(.null) { $0.union($1) }
    }
}
