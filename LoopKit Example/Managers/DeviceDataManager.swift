//
//  DeviceDataManager.swift
//  LoopKit
//
//  Created by Nathan Racklyeft on 3/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import CarbKit
import InsulinKit
import LoopKit


class DeviceDataManager {

    static let sharedManager = DeviceDataManager()

    init() {
        carbStore = CarbStore(
            carbRatioSchedule: carbRatioSchedule,
            insulinSensitivitySchedule: insulinSensitivitySchedule
        )
        doseStore = DoseStore(
            pumpID: nil,
            insulinActionDuration: insulinActionDuration,
            basalProfile: basalRateSchedule,
            insulinSensitivitySchedule: insulinSensitivitySchedule
        )
    }

    // Data stores

    let carbStore: CarbStore?

    let doseStore: DoseStore

    // Settings

    var basalRateSchedule = NSUserDefaults.standardUserDefaults().basalRateSchedule {
        didSet {
            NSUserDefaults.standardUserDefaults().basalRateSchedule = basalRateSchedule

            doseStore.basalProfile = basalRateSchedule
        }
    }

    var carbRatioSchedule = NSUserDefaults.standardUserDefaults().carbRatioSchedule {
        didSet {
            NSUserDefaults.standardUserDefaults().carbRatioSchedule = carbRatioSchedule

            carbStore?.carbRatioSchedule = carbRatioSchedule
        }
    }

    var insulinActionDuration = NSUserDefaults.standardUserDefaults().insulinActionDuration {
        didSet {
            NSUserDefaults.standardUserDefaults().insulinActionDuration = insulinActionDuration

            doseStore.insulinActionDuration = insulinActionDuration
        }
    }

    var insulinSensitivitySchedule = NSUserDefaults.standardUserDefaults().insulinSensitivitySchedule {
        didSet {
            NSUserDefaults.standardUserDefaults().insulinSensitivitySchedule = insulinSensitivitySchedule

            carbStore?.insulinSensitivitySchedule = insulinSensitivitySchedule
            doseStore.insulinSensitivitySchedule = insulinSensitivitySchedule
        }
    }

    var glucoseTargetRangeSchedule = NSUserDefaults.standardUserDefaults().glucoseTargetRangeSchedule {
        didSet {
            NSUserDefaults.standardUserDefaults().glucoseTargetRangeSchedule = glucoseTargetRangeSchedule
        }
    }

}