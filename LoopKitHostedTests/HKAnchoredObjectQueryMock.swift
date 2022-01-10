//
//  HKAnchoredObjectQueryMock.swift
//  LoopKitTests
//
//  Created by Pete Schwamb on 9/2/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

class HKAnchoredObjectQueryMock: HKAnchoredObjectQuery {
    let anchor: HKQueryAnchor?
    let resultsHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void
    
    @available(iOS 15.0, *)
    override init(queryDescriptors: [HKQueryDescriptor],
                  anchor: HKQueryAnchor?,
                  limit: Int,
                  resultsHandler handler: @escaping (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void) {
        self.resultsHandler = handler
        self.anchor = anchor
        super.init(queryDescriptors: queryDescriptors, anchor: anchor, limit: limit, resultsHandler: handler)
    }
    
    override init(type: HKSampleType,
                  predicate: NSPredicate?,
                  anchor: HKQueryAnchor?,
                  limit: Int,
                  resultsHandler handler: @escaping (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void) {
        self.resultsHandler = handler
        self.anchor = anchor
        super.init(type: type, predicate: predicate, anchor: anchor, limit: limit, resultsHandler: handler)
    }
}
