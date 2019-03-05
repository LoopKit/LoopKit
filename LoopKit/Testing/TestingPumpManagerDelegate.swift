//
//  TestingPumpManagerDelegate.swift
//  LoopKit
//
//  Created by Michael Pangburn on 1/14/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import HealthKit


/// Describes a pump manager delegate that provides special privileges to testing-only pump managers.
public protocol TestingPumpManagerDelegate: PumpManagerDelegate {
    func doseStore(for manager: PumpManager) -> TestingPumpDoseStore
}


/// Defines the DoseStore operations made accessible to a testing-only PumpManager.
public final class TestingPumpDoseStore {
    private let doseStore: DoseStore

    public init(doseStore: DoseStore) {
        self.doseStore = doseStore
    }

    private var healthStore: HKHealthStore {
        return doseStore.insulinDeliveryStore.healthStore
    }

    /// Deletes all insulin doses from the device.
    /// This method deletes doses from both the CoreData cache and from HealthKit.
    /// - Parameters:
    ///   - device: The device whose dose data should be deleted from HealthKit.
    ///   - completion: The completion handler.
    public func deleteInsulinDoses(fromDevice device: HKDevice, completion: @escaping (Error?) -> Void) {
        let devicePredicate = HKQuery.predicateForObjects(from: [device])
        deleteInsulinDoses(matching: devicePredicate, completion: completion)
    }

    private func deleteInsulinDoses(matching predicate: NSPredicate, completion: @escaping (Error?) -> Void) {
        // DoseStore.deleteAllPumpEvents first syncs the events to the health store,
        // so HKHealthStore.deleteObjects should catch any that were still in the cache.
        doseStore.deleteAllPumpEvents { doseStoreError in
            if let error = doseStoreError {
                completion(error)
            } else {
                self.healthStore.deleteObjects(of: self.doseStore.sampleType!, predicate: predicate) { success, deletedObjectCount, error in
                    completion(error)
                }
            }
        }
    }
}
