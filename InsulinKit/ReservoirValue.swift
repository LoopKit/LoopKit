//
//  ReservoirValue.swift
//  LoopKit
//
//  Created by Nate Racklyeft on 8/1/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import LoopKit


public protocol ReservoirValue: TimelineValue {
    var startDate: Date { get }
    var unitVolume: Double { get }
}
