//
//  DisplayGlucoseUnitObserver.swift
//  LoopKitUI
//
//  Created by Nathaniel Hamming on 2021-01-13.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import LoopKit

public protocol DisplayGlucoseUnitObserver {
    func unitDidChange(to displayGlucoseUnit: LoopUnit)
}
