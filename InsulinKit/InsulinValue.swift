//
//  InsulinValue.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 4/3/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit


public struct InsulinValue: TimelineValue {
    public let startDate: NSDate
    public let value: Double

    public init(startDate: NSDate, value: Double) {
        self.startDate = startDate
        self.value = value
    }
}
