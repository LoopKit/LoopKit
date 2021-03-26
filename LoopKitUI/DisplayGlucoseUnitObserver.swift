//
//  DisplayGlucoseUnitObserver.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-01-13.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public protocol DisplayGlucoseUnitObserver {
    func displayGlucoseUnitDidChange(to displayGlucoseUnit: HKUnit)
}
