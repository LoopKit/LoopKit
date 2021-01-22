//
//  HealthStoreUnitCache.swift
//  LoopKit
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import HealthKit
import os.log

public extension Notification.Name {
    // used to avoid potential timing issues since a unit change triggers a cache refresh and all stores pull the current unit from the cache
    static let HealthStorePreferredGlucoseUnitDidChange = Notification.Name(rawValue:  "com.loopKit.notification.HealthStorePreferredGlucoseUnitDidChange")
}

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

        userPreferencesChangeObserver = NotificationCenter.default.addObserver(forName: .HKUserPreferencesDidChange, object: healthStore, queue: nil, using: { [weak self] _ in
            DispatchQueue.global().async {
                self?.updateCachedUnits()
            }
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

        return getHealthStoreUnitAndUpdateCache(for: quantityTypeIdentifier)
    }

    @discardableResult private func getHealthStoreUnitAndUpdateCache(for quantityTypeIdentifier: HKQuantityTypeIdentifier) -> HKUnit? {
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

            self.updateCache(for: quantityTypeIdentifier, with: unit)

            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + .seconds(3))
        return unit
    }

    private func updateCachedUnits() {
        let quantityTypeIdentifiers = unitCache.value.keys
        for quantityTypeIdentifier in quantityTypeIdentifiers {
            self.getHealthStoreUnitAndUpdateCache(for: quantityTypeIdentifier)
        }
    }

    private func updateCache(for quantityTypeIdentifier: HKQuantityTypeIdentifier, with unit: HKUnit?) {
        _ = self.unitCache.mutate({ (cache) in
            guard unit != cache[quantityTypeIdentifier] else {
                return
            }

            cache[quantityTypeIdentifier] = unit
            switch quantityTypeIdentifier {
            case .bloodGlucose:
                // currently only changes to glucose unit is reported
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .HealthStorePreferredGlucoseUnitDidChange, object: self.healthStore)
                }
            default:
                break
            }
        })
    }

    deinit {
        if let observer = userPreferencesChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

