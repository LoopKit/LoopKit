//
//  RemoteDataService.swift
//  LoopKit
//
//  Created by Darin Krauss on 5/21/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation

public protocol RemoteDataService: Service {

    func uploadSettings(_ settings: Settings, lastUpdated: Date)

    func uploadLoopStatus(
        insulinOnBoard: InsulinValue?,
        carbsOnBoard: CarbValue?,
        predictedGlucose: [GlucoseValue]?,
        recommendedTempBasal: (recommendation: TempBasalRecommendation, date: Date)?,
        recommendedBolus: Double?,
        lastReservoirValue: ReservoirValue?,
        pumpManagerStatus: PumpManagerStatus?,
        glucoseTargetRangeSchedule: GlucoseRangeSchedule?,
        scheduleOverride: TemporaryScheduleOverride?,
        glucoseTargetRangeScheduleApplyingOverrideIfActive: GlucoseRangeSchedule?,
        loopError: Error?)

    func upload(glucoseValues values: [GlucoseValue], sensorState: SensorDisplayable?)

    func upload(pumpEvents events: [PersistedPumpEvent], fromSource source: String, completion: @escaping (Result<[URL], Error>) -> Void)

    func upload(carbEntries entries: [StoredCarbEntry], completion: @escaping (_ entries: [StoredCarbEntry]) -> Void)

    func delete(carbEntries entries: [DeletedCarbEntry], completion: @escaping (_ entries: [DeletedCarbEntry]) -> Void)

}
