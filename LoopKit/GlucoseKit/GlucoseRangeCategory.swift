//
//  GlucoseRangeCategory.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-23.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation

public enum GlucoseRangeCategory: Int, CaseIterable {
    case belowRange
    case urgentLow
    case low
    case normal
    case high
    case aboveRange
}
