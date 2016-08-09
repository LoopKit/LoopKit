//
//  SampleValue.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/24/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit


public protocol TimelineValue {
    var startDate: NSDate { get }
    var endDate: NSDate { get }
}


public extension TimelineValue {
    var endDate: NSDate {
        return startDate
    }
}


public protocol SampleValue: TimelineValue {
    var quantity: HKQuantity { get }
}


public extension SequenceType where Generator.Element: TimelineValue {
    /**
     Returns the closest element in the sorted sequence prior to the specified date

     - parameter date: The date to use in the search

     - returns: The closest element, if any exist before the specified date
     */
    func closestPriorToDate(date: NSDate) -> Generator.Element? {
        var closestElement: Generator.Element?

        for value in self {
            if value.startDate <= date {
                closestElement = value
            } else {
                break
            }
        }

        return closestElement
    }

    /**
     Returns an array of elements filtered by the specified date range.
     
     This behavior mimics HKQueryOptionNone, where the value must merely overlap the specified range,
     not strictly exist inside of it.

     - parameter startDate: The earliest date of elements to return
     - parameter endDate:   The latest date of elements to return

     - returns: A new array of elements
     */
    func filterDateRange(startDate: NSDate?, _ endDate: NSDate?) -> [Generator.Element] {
        return filter { (value) -> Bool in
            if let startDate = startDate where value.endDate < startDate {
                return false
            }

            if let endDate = endDate where value.startDate > endDate {
                return false
            }

            return true
        }
    }
}
