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
    case noMeal
    case unannouncedMealWithCOB
}

extension UAMTestType {
    var counteractionEffectFixture: String {
        switch self {
        case .noMeal:
            return "no_meal_counteraction_effect"
        case .unannouncedMealWithCOB, .unannouncedMealNoCOB:
            return "uam_counteraction_effect"
        }
    }
    
    var currentDate: Date {
        let dateFormatter = ISO8601DateFormatter.localTimeDate()
        
        switch self {
        case .noMeal:
            return dateFormatter.date(from: "2022-10-17T23:28:45")!
        case .unannouncedMealWithCOB, .unannouncedMealNoCOB:
            return dateFormatter.date(from: "2022-10-17T02:49:16")!
        }
    }
    
    var carbEntries: [NewCarbEntry] {
        let dateFormatter = ISO8601DateFormatter.localTimeDate()
        
        switch self {
        case .unannouncedMealWithCOB:
            return [
                NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 30),
                             startDate: dateFormatter.date(from: "2022-10-14T02:34:22")!,
                             foodType: nil,
                             absorptionTime: nil),
                NewCarbEntry(quantity: HKQuantity(unit: .gram(), doubleValue: 40),
                             startDate: dateFormatter.date(from: "2022-10-17T01:06:52")!,
                             foodType: nil,
                             absorptionTime: nil)
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
    var currentDate: Date!
    
    func setUp(for testType: UAMTestType) -> [GlucoseEffectVelocity] {
        carbStore = CarbStore(
            healthStore: HKHealthStoreMock(),
            cacheStore: cacheStore,
            cacheLength: .hours(24),
            defaultAbsorptionTimes: (fast: .minutes(30), medium: .hours(3), slow: .hours(5)),
            observationInterval: 0,
            overrideHistory: TemporaryScheduleOverrideHistory(),
            provenanceIdentifier: Bundle.main.bundleIdentifier!)
        queryAnchor = CarbStore.QueryAnchor()
        limit = Int.max
        currentDate = testType.currentDate
        
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
    
    func testNoMeal() {
        let counteractionEffects = setUp(for: .noMeal)

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        carbStore.hasUnannouncedMeal(insulinCounteractionEffects: counteractionEffects, currentDate: currentDate) { status in
            XCTAssertEqual(status, .noMeal)
            updateGroup.leave()
        }
        updateGroup.wait()
    }
    
    func testUnannouncedMealNoCarbEntry() {
        let counteractionEffects = setUp(for: .unannouncedMealWithCOB)

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        carbStore.hasUnannouncedMeal(insulinCounteractionEffects: counteractionEffects, currentDate: currentDate) { [unowned self] status in
            let expected = dateFormatter.date(from: "2022-10-17T02:05:00")!
            XCTAssertEqual(status, .hasMeal(startTime: expected))
            updateGroup.leave()
        }
        updateGroup.wait()
    }
    
    func testUnannouncedMealAfterCarbEntry() {
        let counteractionEffects = setUp(for: .unannouncedMealWithCOB)

        let updateGroup = DispatchGroup()
        updateGroup.enter()
        carbStore.hasUnannouncedMeal(insulinCounteractionEffects: counteractionEffects, currentDate: currentDate) { [unowned self] status in
            let expected = dateFormatter.date(from: "2022-10-17T02:05:00")!
            XCTAssertEqual(status, .hasMeal(startTime: expected))
            updateGroup.leave()
        }
        updateGroup.wait()
    }
}
