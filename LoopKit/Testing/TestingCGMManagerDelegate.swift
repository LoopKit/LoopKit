//
//  TestingCGMManagerDelegate.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit


/// Describes a CGM manager delegate that provides special privileges to testing-only pump managers.
public protocol TestingCGMManagerDelegate: CGMManagerDelegate {
    func glucoseStore(for manager: CGMManager) -> TestingCGMGlucoseStore
}


/// Defines the GlucoseStore operations accessible to a testing-only CGMManager.
public final class TestingCGMGlucoseStore {
    private let glucoseStore: GlucoseStore

    public init(glucoseStore: GlucoseStore) {
        self.glucoseStore = glucoseStore
    }

    private var healthStore: HKHealthStore {
        return glucoseStore.healthStore
    }

    public func deleteGlucoseSamples(fromDevice device: HKDevice) {
        let predicate = HKQuery.predicateForObjects(from: [device])
        deleteGlucoseSamples(matching: predicate)
    }

    private func deleteGlucoseSamples(matching predicate: NSPredicate) {
        glucoseStore.purgeGlucoseSamples(matchingCachePredicate: nil, healthKitPredicate: predicate) { success, count, error in
            // result already logged through the store, so ignore the error here
        }
    }
}
