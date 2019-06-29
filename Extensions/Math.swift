//
//  Math.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 3/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


func fractionThrough<T: FloatingPoint>(
    _ value: T,
    in range: ClosedRange<T>,
    using transform: (T) -> T = { $0 }
) -> T {
    let transformedLowerBound = transform(range.lowerBound)
    return (transform(value) - transformedLowerBound) / (transform(range.upperBound) - transformedLowerBound)
}
