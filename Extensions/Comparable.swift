//
//  Comparable.swift
//  LoopKit Example
//
//  Created by Pete Schwamb on 2/17/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        if self < range.lowerBound {
            return range.lowerBound
        } else if self > range.upperBound {
            return range.upperBound
        } else {
            return self
        }
    }
}
