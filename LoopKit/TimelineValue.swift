//
//  TimelineValue.swift
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public protocol TimelineValue {
    var startDate: Date { get }
    var endDate: Date { get }
}


public extension TimelineValue {
    var endDate: Date {
        return startDate
    }
}


public protocol SampleValue: TimelineValue {
    var quantity: LoopQuantity { get }
}


public extension Sequence where Element: TimelineValue {
    /**
     Returns the closest element in the sorted sequence prior to the specified date

     - parameter date: The date to use in the search

     - returns: The closest index, if any exist before the specified date
     */
    func closestPrior(to date: Date) -> Iterator.Element? {
        return elementsAdjacent(to: date).before
    }

    /// Returns the elements immediately before and after the specified date
    ///
    /// - Parameter date: The date to use in the search
    /// - Returns: The closest elements, if found
    func elementsAdjacent(to date: Date) -> (before: Iterator.Element?, after: Iterator.Element?) {
        var before: Iterator.Element?
        var after: Iterator.Element?

        for value in self {
            if value.startDate <= date {
                before = value
            } else {
                after = value
                break
            }
        }

        return (before, after)
    }

    /**
     Returns an array of elements filtered by the specified date range.

     This behavior mimics HKQueryOptionNone, where the value must merely overlap the specified range,
     not strictly exist inside of it.

     - parameter startDate: The earliest date of elements to return
     - parameter endDate:   The latest date of elements to return

     - returns: A new array of elements
     */
    func filterDateRange(_ startDate: Date?, _ endDate: Date?) -> [Iterator.Element] {
        return filter { (value) -> Bool in
            if let startDate = startDate, value.endDate < startDate {
                return false
            }

            if let endDate = endDate, value.startDate > endDate {
                return false
            }

            return true
        }
    }

    /**
     Returns an array of elements filtered by the specified DateInterval.

     This behavior mimics HKQueryOptionNone, where the value must merely overlap the specified range,
     not strictly exist inside of it.

     - parameter startDate: The earliest date of elements to return
     - parameter endDate:   The latest date of elements to return

     - returns: A new array of elements
     */
    func filterDateInterval(interval: DateInterval) -> [Iterator.Element] {
        return filterDateRange(interval.start, interval.end)
    }
}

/// Fast binary-search filter for ordered timeline arrays. Picks up when the
/// collection conforms to RandomAccessCollection with Int index (i.e. Array)
/// and the elements are sorted by startDate (which is the contract for all
/// schedule arrays — sensitivity / basal / carb-ratio / target — across this
/// codebase). Reduces filterDateRange from O(N) to O(log N) per call.
///
/// LoopEval sims with per-step ISF schedules (`--candidate-isf-csv`) call
/// filterDateRange ~1.5M times on a 60-day window; this dropped sim time
/// from ~30 min to ~2 min on that workload.
public extension RandomAccessCollection where Element: TimelineValue, Index == Int {
    func filterDateRange(_ startDate: Date?, _ endDate: Date?) -> [Element] {
        guard !isEmpty else { return [] }
        // This binary-search filter is only correct when the elements are sorted
        // ascending by startDate. Catch contract violations in debug builds; the
        // check is compiled out of release builds, so there is no runtime cost.
        assert(
            zip(self, dropFirst()).allSatisfy { $0.startDate <= $1.startDate },
            "filterDateRange requires elements sorted ascending by startDate"
        )
        // Lower bound: first index where element.endDate >= startDate
        var lo = startIndex
        if let startDate {
            var l = startIndex, r = endIndex
            while l < r {
                let m = (l + r) / 2
                if self[m].endDate < startDate { l = m + 1 } else { r = m }
            }
            lo = l
        }
        // Upper bound: first index where element.startDate > endDate
        var hi = endIndex
        if let endDate {
            var l = lo, r = endIndex
            while l < r {
                let m = (l + r) / 2
                if self[m].startDate <= endDate { l = m + 1 } else { r = m }
            }
            hi = l
        }
        guard lo < hi else { return [] }
        return Array(self[lo..<hi])
    }
}
