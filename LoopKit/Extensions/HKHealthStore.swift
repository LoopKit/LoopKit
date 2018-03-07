//
//  HKHealthStore.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit


protocol HKSampleQueryTestable {
    func executeSampleQuery(
        for type: HKSampleType,
        matching predicate: NSPredicate,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?,
        resultsHandler: @escaping (_ query: HKSampleQuery, _ results: [HKSample]?, _ error: Error?) -> Void
    )
}
