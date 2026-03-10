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
    var isUnitLabelVisible: Bool
    let selectableValues: [Double]

    public init(
        value: Binding<LoopQuantity>,
        unit: LoopUnit,
        guardrail: Guardrail<LoopQuantity>,
        selectableValues: [Double],
        isUnitLabelVisible: Bool = true
    ) {
        self._value = value
        self.unit = unit
        self.guardrail = guardrail
        self.selectableValues = selectableValues
        self.isUnitLabelVisible = isUnitLabelVisible
    }

    public var body: some View {
        QuantityPicker(value: $value,
                       unit: unit,
                       guardrail: guardrail,
                       selectableValues: selectableValues,
                       isUnitLabelVisible: isUnitLabelVisible,
                       guidanceColors: guidanceColors)
    }

}

private struct GlucoseValuePickerTester: View {
    @State var value = LoopQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)

    private let guardrail = Guardrail(absoluteBounds: 54...180, recommendedBounds: 71...120, unit: .milligramsPerDeciliter, startingSuggestion: 80)

    var unit: LoopUnit

    var body: some View {
        GlucoseValuePicker(value: $value, unit: unit, guardrail: guardrail, selectableValues: [100, 105, 110])
    }
}

struct GlucoseValuePicker_Previews: PreviewProvider {
    static var previews: some View {
        ForEach([LoopUnit.milligramsPerDeciliter, .millimolesPerLiter], id: \.self) { unit in
            GlucoseValuePickerTester(unit: unit)
        }
    }
}
