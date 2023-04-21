//
//  Sequence.swift
//  LoopKit
//
//  Created by Michael Pangburn on 6/23/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

extension Sequence {
    func range<Metric: Comparable>(of metricForElement: (Element) throws -> Metric) rethrows -> ClosedRange<Metric>? {
        try lazy.map(metricForElement).reduce(nil) { range, metric in
            if let range = range {
                return range.expandedToInclude(metric)
            } else {
                return metric...metric
            }
        }
    }
}
