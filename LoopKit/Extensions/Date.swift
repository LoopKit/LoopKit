//
//  NSDate.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 1/17/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation


public extension Date {
    func dateFlooredToTimeInterval(_ interval: TimeInterval) -> Date {
        if interval == 0 {
            return self
        }

        return Date(timeIntervalSinceReferenceDate: floor(self.timeIntervalSinceReferenceDate / interval) * interval)
    }

    func dateCeiledToTimeInterval(_ interval: TimeInterval) -> Date {
        if interval == 0 {
            return self
        }

        return Date(timeIntervalSinceReferenceDate: ceil(self.timeIntervalSinceReferenceDate / interval) * interval)
    }
}
