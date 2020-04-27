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
    @Binding var value: HKQuantity
    var unit: HKUnit
    var guardrail: Guardrail<HKQuantity>

    public init(value: Binding<HKQuantity>, unit: HKUnit, guardrail: Guardrail<HKQuantity>) {
        self._value = value
        self.unit = unit
        self.guardrail = guardrail
    }

    public var body: some View {
        QuantityPicker(value: $value, unit: unit, stride: stride, guardrail: guardrail)
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

    private let guardrail = Guardrail(absoluteBounds: 54...180, recommendedBounds: 71...120, unit: .milligramsPerDeciliter)

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
