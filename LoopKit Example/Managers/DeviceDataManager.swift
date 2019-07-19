//
//  DeviceDataManager.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit


class DeviceDataManager : CarbStoreDelegate {

    init() {
        let healthStore = HKHealthStore()
        let cacheStore = PersistenceController(directoryURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!)

        carbStore = CarbStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            carbRatioSchedule: carbRatioSchedule,
            insulinSensitivitySchedule: insulinSensitivitySchedule
        )
        let insulinModel: WalshInsulinModel?
        if let actionDuration = insulinActionDuration {
            insulinModel = WalshInsulinModel(actionDuration: actionDuration)
        } else {
            insulinModel = nil
        }
        doseStore = DoseStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            insulinModel: insulinModel,
            basalProfile: basalRateSchedule,
            insulinSensitivitySchedule: insulinSensitivitySchedule
        )
        glucoseStore = GlucoseStore(healthStore: healthStore, cacheStore: cacheStore)
        carbStore?.delegate = self
    }

    // Data stores

    let carbStore: CarbStore!

    let doseStore: DoseStore

    let glucoseStore: GlucoseStore!

    // Settings

    var basalRateSchedule = UserDefaults.standard.basalRateSchedule {
        didSet {
            UserDefaults.standard.basalRateSchedule = basalRateSchedule

            doseStore.basalProfile = basalRateSchedule
        }
    }

    var carbRatioSchedule = UserDefaults.standard.carbRatioSchedule {
        didSet {
            UserDefaults.standard.carbRatioSchedule = carbRatioSchedule

            carbStore?.carbRatioSchedule = carbRatioSchedule
        }
    }

    var insulinActionDuration = UserDefaults.standard.insulinActionDuration {
        didSet {
            UserDefaults.standard.insulinActionDuration = insulinActionDuration

            if let duration = insulinActionDuration {
                doseStore.insulinModel = WalshInsulinModel(actionDuration: duration)
            }
        }
    }

    var insulinSensitivitySchedule = UserDefaults.standard.insulinSensitivitySchedule {
        didSet {
            UserDefaults.standard.insulinSensitivitySchedule = insulinSensitivitySchedule

            carbStore?.insulinSensitivitySchedule = insulinSensitivitySchedule
            doseStore.insulinSensitivitySchedule = insulinSensitivitySchedule
        }
    }

    var glucoseTargetRangeSchedule = UserDefaults.standard.glucoseTargetRangeSchedule {
        didSet {
            UserDefaults.standard.glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        }
    }

    public var preMealTargetRange: DoubleRange? = UserDefaults.standard.preMealTargetRange {
        didSet {
            UserDefaults.standard.preMealTargetRange = preMealTargetRange
        }
    }

    public var legacyWorkoutTargetRange: DoubleRange? = UserDefaults.standard.legacyWorkoutTargetRange {
        didSet {
            UserDefaults.standard.legacyWorkoutTargetRange = legacyWorkoutTargetRange
        }
    }

    var pumpID = UserDefaults.standard.pumpID {
        didSet {
            UserDefaults.standard.pumpID = pumpID

            if pumpID != oldValue {
                doseStore.resetPumpData()
            }
        }
    }

    // MARK: CarbStoreDelegate

    func carbStore(_ carbStore: CarbStore, didError error: CarbStore.CarbStoreError) {
        print("carbstore error: \(error)")
    }
}
