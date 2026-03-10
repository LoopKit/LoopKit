//
//  Binding.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LoopAlgorithm


extension Binding where Value == Double {
    func withUnit(_ unit: LoopUnit) -> Binding<LoopQuantity> {
        Binding<LoopQuantity>(
            get: { LoopQuantity(unit: unit, doubleValue: self.wrappedValue) },
            set: { self.wrappedValue = $0.doubleValue(for: unit) }
        )
    }
}

extension Binding where Value == LoopQuantity {
    func doubleValue(for unit: LoopUnit) -> Binding<Double> {
        Binding<Double>(
            get: { self.wrappedValue.doubleValue(for: unit) },
            set: { self.wrappedValue = LoopQuantity(unit: unit, doubleValue: $0) }
        )
    }
}
