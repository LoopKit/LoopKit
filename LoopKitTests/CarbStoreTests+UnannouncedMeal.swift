//
//  CarbStoreTests+UnannouncedMeal.swift
//  LoopKitTests
//
//  Created by Anna Quinlan on 10/17/22.
//  Copyright © 2022 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

enum UAMTestType {
    private static var dateFormatter = ISO8601DateFormatter.localTimeDate()
    
    /// No meal is present
    case noMeal
    /// No meal is present, but if the counteraction effects aren't clamped properly it will look like there's a UAM
    case noMealCounteractionEffectsNeedClamping
    /// UAM with no carbs on board
    case unannouncedMealNoCOB
    /// UAM with carbs logged prior to it
    case unannouncedMealWithCOB
    /// There is a meal, but it's announced and not unannounced
    case announcedMeal
    /// CGM data is noisy, but no meal is present
    case noisyCGM
    // ANNA TODO: add more cases
}

extension UAMTestType {
    var counteractionEffectFixture: String {
        switch self {
        case .unannouncedMealNoCOB:
            return "uam_counteraction_effect"
        case .noMeal, .unannouncedMealWithCOB, .announcedMeal:
            return "long_interval_counteraction_effect"
        case .noMealCounteractionEffectsNeedClamping:
            return "needs_clamping_counteraction_effect"
        case .noisyCGM:
            return "noisy_cgm_counteraction_effect"
        }
    }
    
    var currentDate: Date {
        switch self {
        case .unannouncedMealNoCOB:
            return Self.dateFormatter.date(from: "2022-10-17T23:28:45")!
        case .unannouncedMealWithCOB, .noMeal, .noMealCounteractionEffectsNeedClamping, .announcedMeal:
            return Self.dateFormatter.date(from: "2022-10-17T02:49:16")!
        case .noisyCGM:
            return Self.dateFormatter.date(from: "2022-10-19T20:46:23")!
        }
    }
    
    var uamDate: Date? {
        switch self {
        case .unannouncedMealNoCOB:
            return Self.dateFormatter.date(from: "2022-10-17T22:40:00")
        case .unannouncedMealWithCOB:
            return Self.dateFormatter.date(from: "2022-10-17T02:15:00")
        default:
            return nil
        }
    }
    
    var carbEntries: [NewCarbEntry] {
        switch self {
        case .unannouncedMealWithCOB:
            return [
                NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 30),
                             startDate: Self.dateFormatter.date(from: "2022-10-14T02:34:22")!,
                             foodType: nil,
                             absorptionTime: nil),
                NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 40),
                             startDate: Self.dateFormatter.date(from: "2022-10-17T01:06:52")!,
                             foodType: nil,
                             absorptionTime: nil)
            ]
        case .announcedMeal:
            return [
                NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 30),
                             startDate: Self.dateFormatter.date(from: "2022-10-14T02:34:22")!,
                             foodType: nil,
                             absorptionTime: nil),
                NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 40),
                             startDate: Self.dateFormatter.date(from: "2022-10-17T01:06:52")!,
                             foodType: nil,
                             absorptionTime: nil),
                NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 1),
                             startDate: Self.dateFormatter.date(from: "2022-10-17T02:15:00")!,
                             foodType: nil,
                             absorptionTime: nil),
            ]
        default:
            return []
        }
    }
}

class CarbStoreUnannouncedMealTests: PersistenceControllerTestCase {
    let dateFormatter = ISO8601DateFormatter.localTimeDate()
    
    var carbStore: CarbStore!
    var queryAnchor: CarbStore.QueryAnchor!
    var limit: Int!
    
    func setUp(for testType: UAMTestType) -> [GlucoseEffectVelocity] {
        let healthStore = HKHealthStoreMock()
        
        carbStore = CarbStore(
            healthStore: healthStore,
            cacheStore: cacheStore,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: 0,
            overrideHistory: TemporaryScheduleOverrideHistory(),
            provenanceIdentifier: Bundle.main.bundleIdentifier!,
            test_currentDate: testType.currentDate)
        queryAnchor = CarbStore.QueryAnchor()
        limit = Int.max
        
        // Set up schedules
        let carbSchedule = CarbRatioSchedule(
            unit: .gram(),
            dailyItems: [
                RepeatingScheduleValue(startTime: 0.0, value: 15.0),
            ],
            timeZone: .utcTimeZone
        )!
        carbStore.carbRatioSchedule = carbSchedule

        let insulinSensitivitySchedule = InsulinSensitivitySchedule(
            unit: HKUnit.milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0.0, value: 50.0)
            ],
            timeZone: .utcTimeZone
        )!
        carbStore.insulinSensitivitySchedule = insulinSensitivitySchedule

        // Add any needed carb entries to the carb store
        let updateGroup = DispatchGroup()
        testType.carbEntries.forEach { carbEntry in
            updateGroup.enter()
            carbStore.addCarbEntry(carbEntry) { result in
                if case .failure(_) = result {
                    XCTFail("Failed to add carb entry to carb store")
                }

                updateGroup.leave()
            }
        }
        _ = updateGroup.wait(timeout: .now() + .seconds(5))
        
        // Fetch & return the counteraction effects for the test
        return counteractionEffects(for: testType)
    }
    
    private func counteractionEffects(for testType: UAMTestType) -> [GlucoseEffectVelocity] {
        let fixture: [JSONDictionary] = loadFixture(testType.counteractionEffectFixture)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            GlucoseEffectVelocity(startDate: dateFormatter.date(from: $0["startDate"] as! String)!,
                                  endDate: dateFormatter.date(from: $0["endDate"] as! String)!,
                                  quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String),
                                                       doubleValue:$0["value"] as! Double))
        }
    }
    
    override func tearDown() {
        limit = nil
        queryAnchor = nil
        carbStore = nil
        
        super.tearDown()
    }
    
    func testNoUnannouncedMeal() {
        let counteractionEffects = setUp(for: .noMeal)

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        carbStore.hasUnannouncedMeal(insulinCounteractionEffects: counteractionEffects) { status in
            XCTAssertEqual(status, .noUnannouncedMeal)
            updateGroup.leave()
        }
        updateGroup.wait()
    }
    
    func testUnannouncedMeal_NoCarbEntry() {
        let testType = UAMTestType.unannouncedMealNoCOB
        let counteractionEffects = setUp(for: testType)

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        carbStore.hasUnannouncedMeal(insulinCounteractionEffects: counteractionEffects) { status in
            XCTAssertEqual(status, .hasUnannouncedMeal(startTime: testType.uamDate!))
            updateGroup.leave()
        }
        updateGroup.wait()
    }
    
    func testUnannouncedMeal_AfterCarbEntry() {
        let testType = UAMTestType.unannouncedMealWithCOB
        let counteractionEffects = setUp(for: testType)

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        carbStore.hasUnannouncedMeal(insulinCounteractionEffects: counteractionEffects) { status in
            XCTAssertEqual(status, .hasUnannouncedMeal(startTime: testType.uamDate!))
            updateGroup.leave()
        }
        updateGroup.wait()
    }
    
    func testNoUnannouncedMeal_AnnouncedMealPresent() {
        let counteractionEffects = setUp(for: .announcedMeal)

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        carbStore.hasUnannouncedMeal(insulinCounteractionEffects: counteractionEffects) { status in
            XCTAssertEqual(status, .noUnannouncedMeal)
            updateGroup.leave()
        }
        updateGroup.wait()
    }
    
    func testNoisyCGM() {
        let counteractionEffects = setUp(for: .noisyCGM)

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        carbStore.hasUnannouncedMeal(insulinCounteractionEffects: counteractionEffects) { status in
            XCTAssertEqual(status, .noUnannouncedMeal)
            updateGroup.leave()
        }
        updateGroup.wait()
    }
}
