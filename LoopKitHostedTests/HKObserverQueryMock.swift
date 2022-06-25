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
    
    @available(iOS 15.0, *)
    override init(queryDescriptors: [HKQueryDescriptor], updateHandler: @escaping (HKObserverQuery, Set<HKSampleType>?, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) {
        self.updateHandler = {
            updateHandler($0, nil, $1, $2)
        }
        super.init(queryDescriptors: queryDescriptors, updateHandler: updateHandler)
    }
    
    override init(sampleType: HKSampleType, predicate: NSPredicate?, updateHandler: @escaping (HKObserverQuery, @escaping HKObserverQueryCompletionHandler, Error?) -> Void) {
        self.updateHandler = updateHandler
        super.init(sampleType: sampleType, predicate: predicate, updateHandler: updateHandler)
    }
}
