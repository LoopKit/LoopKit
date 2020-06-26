//
//  GlucoseValueType+Color.swift
//  LoopKit
//
//  Created by Nathaniel Hamming on 2020-06-22.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

extension GlucoseValueType {
    public var color: UIColor {
        switch self {
        case .normal:
            return .label
        case .low, .belowRange:
            return .systemRed
        case .high, .aboveRange:
            // TODO confirm this is the correct orange
            return .systemOrange
        }
    }
}
