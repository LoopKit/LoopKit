//
//  PreferredGlucoseUnitObserver.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-01-13.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public protocol PreferredGlucoseUnitObserver {
    func preferredGlucoseUnitDidChange(to preferredGlucoseUnit: HKUnit)
}
