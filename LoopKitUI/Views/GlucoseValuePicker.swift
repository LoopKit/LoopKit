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
import LoopAlgorithm

public struct GlucoseValuePicker: View {
    @Environment(\.guidanceColors) var guidanceColors
    @Binding var value: LoopQuantity
    var unit: LoopUnit
    var guardrail: Guardrail<LoopQuantity>
    var bounds: ClosedRange<LoopQuantity>
    var isUnitLabelVisible: Bool

    public init(
        value: Binding<LoopQuantity>,
        unit: LoopUnit,
        guardrail: Guardrail<LoopQuantity>,
        bounds: ClosedRange<LoopQuantity>,
        isUnitLabelVisible: Bool = true
    ) {
        self._value = value
        self.unit = unit
        self.guardrail = guardrail
        self.bounds = bounds
        self.isUnitLabelVisible = isUnitLabelVisible
    }

    public init(
        value: Binding<LoopQuantity>,
        unit: LoopUnit,
        guardrail: Guardrail<LoopQuantity>,
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

    var selectableValues: [Double] {
        Array(
            Swift.stride(
                from: bounds.lowerBound.doubleValue(for: unit),
                through: bounds.upperBound.doubleValue(for: unit),
                by: stride.doubleValue(for: unit)
            )
        )
    }

    private var stride: LoopQuantity {
        switch unit {
        case .milligramsPerDeciliter:
            return LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 1)
        case .millimolesPerLiter:
            return LoopQuantity(unit: .millimolesPerLiter, doubleValue: 0.1)
        default:
            fatalError("Unsupported glucose unit \(unit)")
        }
    }
}

private struct GlucoseValuePickerTester: View {
    @State var value = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)

    private let guardrail = Guardrail(absoluteBounds: 54...180, recommendedBounds: 71...120, unit: .milligramsPerDeciliter, startingSuggestion: 80)

    var unit: LoopUnit

    var body: some View {
        GlucoseValuePicker(value: $value, unit: unit, guardrail: guardrail)
    }
}

struct GlucoseValuePicker_Previews: PreviewProvider {
    static var previews: some View {
        ForEach([LoopUnit.milligramsPerDeciliter, .millimolesPerLiter], id: \.self) { unit in
            GlucoseValuePickerTester(unit: unit)
        }
    }
}
