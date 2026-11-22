//
//  PumpSupportedIncrements.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/16/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

import LoopKit

public struct PumpSupportedIncrements {
    let basalRates: [Double]
    let bolusVolumes: [Double]
    let maximumBolusVolumes: [Double]
    let maximumBasalScheduleEntryCount: Int
    public init(basalRates: [Double], bolusVolumes: [Double], maximumBolusVolumes: [Double], maximumBasalScheduleEntryCount: Int) {
        self.basalRates = basalRates
        self.bolusVolumes = bolusVolumes
        self.maximumBolusVolumes = maximumBolusVolumes
        self.maximumBasalScheduleEntryCount = maximumBasalScheduleEntryCount
    }
}

extension TherapyProfileValidator {
    /// The checks for activating a profile with `therapySettings` on the pump with `pumpSupportedIncrements`, or nil
    /// without a pump.
    public init?(therapySettings: TherapySettings, pumpSupportedIncrements: PumpSupportedIncrements?) {
        guard let pumpSupportedIncrements else {
            return nil
        }
        self.init(supportedBasalRates: pumpSupportedIncrements.basalRates,
                  maximumBasalRatePerHour: therapySettings.maximumBasalRatePerHour,
                  maximumBasalScheduleEntryCount: pumpSupportedIncrements.maximumBasalScheduleEntryCount,
                  suspendThreshold: therapySettings.suspendThreshold)
    }

    /// One line per failing schedule, "Basal Rates: reason", in the order the schedules are shown.
    public static func description(of failures: [TherapyProfileSchedule: TherapyProfileError]) -> String {
        TherapyProfileSchedule.allCases.compactMap { schedule in
            failures[schedule].map { "\(schedule.therapySetting.title): \($0.localizedDescription)" }
        }.joined(separator: "\n")
    }
}
