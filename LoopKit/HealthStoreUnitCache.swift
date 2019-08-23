//
//  HealthStoreUnitCache.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import os.log


public class HealthStoreUnitCache {
    private static var cacheCache = NSMapTable<HKHealthStore, HealthStoreUnitCache>.weakToStrongObjects()

    public let healthStore: HKHealthStore

    private static let fixedUnits: [HKQuantityTypeIdentifier: HKUnit] = [
        .dietaryCarbohydrates: .gram(),
        .insulinDelivery: .internationalUnit()
    ]

    private var unitCache = Locked([HKQuantityTypeIdentifier: HKUnit]())

    private var userPreferencesChangeObserver: Any?

    private init(healthStore: HKHealthStore) {
        self.healthStore = healthStore

        userPreferencesChangeObserver = NotificationCenter.default.addObserver(forName: .HKUserPreferencesDidChange, object: healthStore, queue: nil, using: { [weak self] (_) in
            _ = self?.unitCache.mutate({ (cache) in
                cache.removeAll()
            })
        })
    }

    public class func unitCache(for healthStore: HKHealthStore) -> HealthStoreUnitCache {
        if let cache = cacheCache.object(forKey: healthStore) {
            return cache
        }

        let cache = HealthStoreUnitCache(healthStore: healthStore)
        cacheCache.setObject(cache, forKey: healthStore)
        return cache
    }

    public func preferredUnit(for quantityTypeIdentifier: HKQuantityTypeIdentifier) -> HKUnit? {
        if let unit = HealthStoreUnitCache.fixedUnits[quantityTypeIdentifier] {
            return unit
        }

        if let unit = unitCache.value[quantityTypeIdentifier] {
            return unit
        }

        guard let quantityType = HKQuantityType.quantityType(forIdentifier: quantityTypeIdentifier) else {
            return nil
        }

        var unit: HKUnit?
        let semaphore = DispatchSemaphore(value: 0)

        healthStore.preferredUnits(for: [quantityType]) { (results, error) in
            if let error = error {
                // This is a common/expected case when protected data is unavailable
                OSLog(category: "HealthStoreUnitCache").info("Error fetching unit for %{public}@: %{public}@", quantityTypeIdentifier.rawValue, String(describing: error))
            }

            unit = results[quantityType]

            _ = self.unitCache.mutate({ (cache) in
                cache[quantityTypeIdentifier] = unit
            })

            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + .seconds(3))
        return unit
    }

    deinit {
        if let observer = userPreferencesChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

