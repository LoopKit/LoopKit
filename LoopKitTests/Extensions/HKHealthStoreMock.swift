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
    var lastQuery: HKQuery?

    private var saveHandler: ((_ objects: [HKObject], _ success: Bool, _ error: Error?) -> Void)?

    let queue = DispatchQueue(label: "HKHealthStoreMock")

    override func save(_ objects: [HKObject], withCompletion completion: @escaping (Bool, Error?) -> Void) {
        queue.async {
            completion(self.saveError == nil, self.saveError)
            self.saveHandler?(objects, self.saveError == nil, self.saveError)
        }
    }

    override func delete(_ objects: [HKObject], withCompletion completion: @escaping (Bool, Error?) -> Void) {
        queue.async {
            completion(self.deleteError == nil, self.deleteError)
        }
    }

    override func deleteObjects(of objectType: HKObjectType, predicate: NSPredicate, withCompletion completion: @escaping (Bool, Int, Error?) -> Void) {
        queue.async {
            completion(self.deleteError == nil, 0, self.deleteError)
        }
    }

    func setSaveHandler(_ saveHandler: ((_ objects: [HKObject], _ success: Bool, _ error: Error?) -> Void)?) {
        queue.sync {
            self.saveHandler = saveHandler
        }
    }
}

extension HKHealthStoreMock {

    override func execute(_ query: HKQuery) {
        self.lastQuery = query
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
