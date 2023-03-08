//
//  Math.swift
//  LoopKitUI
//
//  Created by Michael Pangburn on 3/23/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//


func fractionThrough<Metric: FloatingPoint>(
    _ value: Metric,
    in range: ClosedRange<Metric>,
    using transform: (Metric) -> Metric = { $0 }
) -> Metric {
    let transformedLowerBound = transform(range.lowerBound)
    return (transform(value) - transformedLowerBound) / (transform(range.upperBound) - transformedLowerBound)
}

func interpolatedValue<Metric: FloatingPoint>(
    at fraction: Metric,
    through range: ClosedRange<Metric>
) -> Metric {
    fraction * (range.upperBound - range.lowerBound) + range.lowerBound
}
