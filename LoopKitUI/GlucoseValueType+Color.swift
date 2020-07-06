//
//  GlucoseValueType+Color.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-22.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

extension GlucoseValueType {
    public var glucoseColor: UIColor {
        switch self {
        case .low, .normal, .high:
            return .label
        case .urgentLow, .belowRange:
            return .systemRed
        case .aboveRange:
            return .systemOrange
        }
    }
    
    public var trendColor: UIColor {
        switch self {
        case .normal:
            return .systemPurple
        case .urgentLow, .low, .belowRange:
            return .systemRed
        case .high, .aboveRange:
            return .systemOrange
        }
    }
}
