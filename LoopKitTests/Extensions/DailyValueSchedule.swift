//
//  DailyValueSchedule.swift
//  LoopKitTests
//
//  Created by Michael Pangburn on 3/25/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import LoopKit


extension DailyValueSchedule where T: FloatingPoint {
    func equals(_ other: DailyValueSchedule<T>, accuracy epsilon: T) -> Bool {
        guard items.count == other.items.count else { return false }
        return Swift.zip(items, other.items).allSatisfy { thisItem, otherItem in
            thisItem.startTime == otherItem.startTime
                && abs(thisItem.value - otherItem.value) <= epsilon
        }
    }
}
