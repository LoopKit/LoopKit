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


class DeviceDataManager {

    init() {
        healthStore = HKHealthStore()
        let cacheStore = PersistenceController(directoryURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!)

        let observationInterval: TimeInterval = .hours(24)

        carbSampleStore = HealthKitSampleStore(
            healthStore: healthStore,
            observeHealthKitSamplesFromOtherApps: false,
            type: HealthKitSampleStore.carbType,
            observationStart: Date().addingTimeInterval(-observationInterval),
            observationEnabled: false)

        carbStore = CarbStore(
            healthKitSampleStore: carbSampleStore,
            cacheStore: cacheStore,
            cacheLength: observationInterval,
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            carbRatioSchedule: carbRatioSchedule,
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            provenanceIdentifier: HKSource.default().bundleIdentifier
        )

        doseSampleStore = HealthKitSampleStore(
            healthStore: healthStore,
            observeHealthKitSamplesFromOtherApps: false,
            type: HealthKitSampleStore.insulinQuantityType,
            observationStart: Date().addingTimeInterval(-observationInterval),
            observationEnabled: false)

        doseStore = DoseStore(
            healthKitSampleStore: doseSampleStore,
            cacheStore: cacheStore,
            insulinModelProvider: PresetInsulinModelProvider(defaultRapidActingModel: ExponentialInsulinModelPreset.rapidActingAdult),
            longestEffectDuration: ExponentialInsulinModelPreset.rapidActingAdult.effectDuration,
            basalProfile: basalRateSchedule,
            insulinSensitivitySchedule: insulinSensitivitySchedule,
            provenanceIdentifier: HKSource.default().bundleIdentifier
        )


        glucoseSampleStore = HealthKitSampleStore(
            healthStore: healthStore,
            observeHealthKitSamplesFromOtherApps: false,
            type: HealthKitSampleStore.glucoseType,
            observationStart: Date().addingTimeInterval(-observationInterval),
            observationEnabled: false)

        glucoseStore = GlucoseStore(
            healthKitSampleStore: glucoseSampleStore,
            cacheStore: cacheStore,
            provenanceIdentifier: HKSource.default().bundleIdentifier)
    }

    // Data stores
    let healthStore: HKHealthStore

    let carbSampleStore: HealthKitSampleStore!
    let carbStore: CarbStore!

    let doseSampleStore: HealthKitSampleStore!
    let doseStore: DoseStore

    let glucoseSampleStore: HealthKitSampleStore!
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

    func carbStoreHasUpdatedCarbData(_ carbStore: CarbStore) {}

    func carbStore(_ carbStore: CarbStore, didError error: CarbStore.CarbStoreError) {
        print("carbstore error: \(error)")
    }
}
