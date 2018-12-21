//
//  CGMDataStore.swift
//  LoopKit
//
//  Created by Michael Pangburn on 12/4/18.
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit


/// Defines the GlucoseStore operations accessible to a CGMManager.
public final class CGMDataStore {
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
