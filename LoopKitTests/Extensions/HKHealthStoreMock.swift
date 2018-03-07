//
//  HKHealthStoreMock.swift
//  LoopKitTests
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import Foundation
@testable import LoopKit


class HKHealthStoreMock: HKHealthStore {
    var saveError: Error?
    var deleteError: Error?
    var queryResults: (samples: [HKSample]?, error: Error?)?

    let queue = DispatchQueue(label: "HKHealthStoreMock")

    override func save(_ objects: [HKObject], withCompletion completion: @escaping (Bool, Error?) -> Void) {
        queue.async {
            completion(self.saveError == nil, self.saveError)
        }
    }

    override func delete(_ objects: [HKObject], withCompletion completion: @escaping (Bool, Error?) -> Void) {
        queue.async {
            completion(self.deleteError == nil, self.deleteError)
        }
    }
}


extension HKHealthStoreMock: HKSampleQueryTestable {
    func executeSampleQuery(
        for type: HKSampleType,
        matching predicate: NSPredicate,
        limit: Int,
        sortDescriptors: [NSSortDescriptor]?,
        resultsHandler: @escaping (_ query: HKSampleQuery, _ results: [HKSample]?, _ error: Error?) -> Void
    ) {
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: sortDescriptors, resultsHandler: resultsHandler)

        guard let results = queryResults else {
            execute(query)
            return
        }

        queue.async {
            resultsHandler(query, results.samples, results.error)
        }
    }
}
