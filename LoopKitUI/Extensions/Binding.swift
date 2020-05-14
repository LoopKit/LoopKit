//
//  Binding.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 5/13/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import SwiftUI
import HealthKit


extension Binding where Value == Double {
    func withUnit(_ unit: HKUnit) -> Binding<HKQuantity> {
        Binding<HKQuantity>(
            get: { HKQuantity(unit: unit, doubleValue: self.wrappedValue) },
            set: { self.wrappedValue = $0.doubleValue(for: unit) }
        )
    }
}
