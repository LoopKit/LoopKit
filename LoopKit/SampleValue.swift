//
//  SampleValue.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopAlgorithm

public extension Sequence where Element: TimelineValue {
    /// Returns all elements inmmediately adjacent to the specified date
    ///
    /// Use Sequence.elementsAdjacent(to:) if specific before/after references are necessary
    ///
    /// - Parameter date: The date to use in the search
    /// - Returns: The closest elements, if found
    func allElementsAdjacent(to date: Date) -> [Iterator.Element] {
        let (before, after) = elementsAdjacent(to: date)
        return [before, after].compactMap({ $0 })
    }
}
