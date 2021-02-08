//
//  HKObserverQueryMock.swift
//  LoopKitHostedTests
//
//  Created by Pete Schwamb on 9/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

class HKObserverQueryMock: HKObserverQuery {
    let updateHandler: (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void
    
    override init(sampleType: HKSampleType, predicate: NSPredicate?, updateHandler: @escaping (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) {
        self.updateHandler = updateHandler
        super.init(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
    }
}
