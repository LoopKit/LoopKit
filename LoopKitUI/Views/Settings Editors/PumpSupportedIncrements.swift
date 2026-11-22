//
//  PumpSupportedIncrements.swift
//  LoopKitUI
//
//  Created by Rick Pasetto on 7/16/20.
//  Copyright © 2020 LoopKit Authors. All rights reserved.
//

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
