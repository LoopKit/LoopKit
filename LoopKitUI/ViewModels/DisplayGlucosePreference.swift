//
//  DisplayGlucosePreference.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-03-10.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import SwiftUI
import LoopKit

public class DisplayGlucosePreference: ObservableObject {
    @Published public private(set) var unit: HKUnit
    @Published public private(set) var formatter: QuantityFormatter

    public init(displayGlucoseUnit: HKUnit) {
        self.unit = displayGlucoseUnit
        self.formatter = QuantityFormatter(for: displayGlucoseUnit)
    }
}

extension DisplayGlucosePreference: DisplayGlucoseUnitObserver {
    public func displayGlucoseUnitDidChange(to displayGlucoseUnit: HKUnit) {
        self.unit = displayGlucoseUnit
        self.formatter = QuantityFormatter(for: displayGlucoseUnit)
    }
}
