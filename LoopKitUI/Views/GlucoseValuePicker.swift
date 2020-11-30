//
//  GlucoseValuePicker.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 4/14/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit
import LoopKit


public struct GlucoseValuePicker: View {
    @Environment(\.guidanceColors) var guidanceColors
    @Binding var value: HKQuantity
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>
    var bounds: ClosedRange<HKQuantity>
    var isUnitLabelVisible: Bool

    public init(
        value: Binding<HKQuantity>,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        bounds: ClosedRange<HKQuantity>,
        isUnitLabelVisible: Bool = true
    ) {
        self._value = value
        self.unit = unit
        self.guardrail = guardrail
        self.bounds = bounds
        self.isUnitLabelVisible = isUnitLabelVisible
    }

    public init(
        value: Binding<HKQuantity>,
        unit: HKUnit,
        guardrail: Guardrail<HKQuantity>,
        isUnitLabelVisible: Bool = true
    ) {
        self.init(value: value, unit: unit, guardrail: guardrail, bounds: guardrail.absoluteBounds, isUnitLabelVisible: isUnitLabelVisible)
    }

    public var body: some View {
        QuantityPicker(value: $value,
                       unit: unit,
                       guardrail: guardrail,
                       selectableValues: selectableValues,
                       isUnitLabelVisible: isUnitLabelVisible,
                       guidanceColors: guidanceColors)
    }

    private var selectableValues: [Double] {
        Array(Swift.stride(
            from: bounds.lowerBound.doubleValue(for: unit),
            through: bounds.upperBound.doubleValue(for: unit),
            by: stride.doubleValue(for: unit)
        ))
    }

    private var stride: HKQuantity {
        switch unit {
        case .milligramsPerDeciliter:
            return HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 1)
        case .millimolesPerLiter:
            return HKQuantity(unit: .millimolesPerLiter, doubleValue: 0.1)
        default:
            fatalError("Unsupported glucose unit \(unit)")
        }
    }
}

private struct GlucoseValuePickerTester: View {
    @State var value = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)

    private let guardrail = Guardrail(absoluteBounds: 54...180, recommendedBounds: 71...120, unit: .milligramsPerDeciliter, startingSuggestion: 80)

    var unit: HKUnit

    var body: some View {
        GlucoseValuePicker(value: $value, unit: unit, guardrail: guardrail)
    }
}

struct GlucoseValuePicker_Previews: PreviewProvider {
    static var previews: some View {
        ForEach([HKUnit.milligramsPerDeciliter, .millimolesPerLiter], id: \.self) { unit in
            GlucoseValuePickerTester(unit: unit)
        }
    }
}
