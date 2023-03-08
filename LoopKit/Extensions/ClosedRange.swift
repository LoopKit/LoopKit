//
//  ClosedRange.swift
//  LoopKit
//
//  Created by Michael Pangburn on 6/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

extension ClosedRange {
    func expandedToInclude(_ value: Bound) -> ClosedRange {
        if value < lowerBound {
            return value...upperBound
        } else if value > upperBound {
            return lowerBound...value
        } else {
            return self
        }
    }
}
