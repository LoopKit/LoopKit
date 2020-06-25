//
//  HKQuery.swift
//  LoopKit
//
//  Created by Rick Pasetto on 6/22/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import HealthKit

extension HKQuery {
    public class func predicateForSamples(observeHealthKitForCurrentAppOnly: Bool, withStart startDate: Date?, end endDate: Date?, options: HKQueryOptions = []) -> NSPredicate {
        if observeHealthKitForCurrentAppOnly {
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForObjects(from: HKSource.default()),
                HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            ])
        } else {
            return HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        }
    }
}
