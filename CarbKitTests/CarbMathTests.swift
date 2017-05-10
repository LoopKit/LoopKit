//
//  CarbMathTests.swift
//  CarbKitTests
//
//  Created by Nathan Racklyeft on 1/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
@testable import CarbKit
import LoopKit
import HealthKit


class CarbMathTests: XCTestCase {

    private func loadSchedules() -> (CarbRatioSchedule, InsulinSensitivitySchedule) {
        let fixture: JSONDictionary = loadFixture("read_carb_ratios")
        let schedule = fixture["schedule"] as! [JSONDictionary]

        let items = schedule.map {
            return RepeatingScheduleValue(startTime: TimeInterval(minutes: $0["offset"] as! Double), value: $0["ratio"] as! Double)
        }

        return (
            CarbRatioSchedule(unit: HKUnit.gram(), dailyItems: items)!,
            InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliterUnit(), dailyItems: [RepeatingScheduleValue(startTime: 0.0, value: 40.0)])!
        )
    }

    private func loadHistoryFixture(_ name: String) -> [NewCarbEntry] {
        let fixture: [JSONDictionary] = loadFixture(name)
        return carbEntriesFromFixture(fixture)
    }

    private func carbEntriesFromFixture(_ fixture: [JSONDictionary]) -> [NewCarbEntry] {
        let dateFormatter = DateFormatter.ISO8601LocalTime()

        return fixture.map {
            return NewCarbEntry(
                quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue: $0["amount"] as! Double),
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                foodType: nil,
                absorptionTime: nil
            )
        }
    }

    private func loadEffectOutputFixture() -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture("carb_effect_from_history_output")
        let dateFormatter = DateFormatter.ISO8601LocalTime()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    private func loadCOBOutputFixture() -> [CarbValue] {
        let fixture: [JSONDictionary] = loadFixture("carbs_on_board_output")
        let dateFormatter = DateFormatter.ISO8601LocalTime()

        return fixture.map {
            return CarbValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    func testCarbEffectFromHistory() {
        let input = loadHistoryFixture("carb_effect_from_history_input")
        let output = loadEffectOutputFixture()
        let (carbRatios, insulinSensitivities) = loadSchedules()

        let effects = CarbMath.glucoseEffectsForCarbEntries(input, carbRatios: carbRatios, insulinSensitivities: insulinSensitivities, defaultAbsorptionTime: TimeInterval(minutes: 180))

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliterUnit()), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliterUnit()), accuracy: pow(10, -11))
        }
    }

    func testCarbsOnBoardFromHistory() {
        let input = loadHistoryFixture("carb_effect_from_history_input")
        let output = loadCOBOutputFixture()

        let cob = CarbMath.carbsOnBoardForCarbEntries(input, defaultAbsorptionTime: TimeInterval(minutes: 180), delay: TimeInterval(minutes: 10), delta: TimeInterval(minutes: 5))

        XCTAssertEqual(output.count, cob.count)

        for (expected, calculated) in zip(output, cob) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqualWithAccuracy(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: pow(10, -11))
        }
    }

    func testGroupedByOverlappingAbsorptionTimeFromHistory() {
        let input = loadHistoryFixture("grouped_by_overlapping_absorption_times_input")
        let outputFixture: [[JSONDictionary]] = loadFixture("grouped_by_overlapping_absorption_times_output")
        let output = outputFixture.map { self.carbEntriesFromFixture($0) }
        let grouped = CarbMath.groupedByOverlappingAbsorptionTimes(input, defaultAbsorptionTime: TimeInterval(minutes: 180))

        XCTAssertEqual(output.count, grouped.count)

        for (expected, calculated) in zip(output, grouped) {
            XCTAssertEqual(expected, calculated)
        }
    }

    func testGroupedByOverlappingAbsorptionTimeEdgeCases() {
        let input = loadHistoryFixture("grouped_by_overlapping_absorption_times_border_case_input")
        let outputFixture: [[JSONDictionary]] = loadFixture("grouped_by_overlapping_absorption_times_border_case_output")
        let output = outputFixture.map { self.carbEntriesFromFixture($0) }
        let grouped = CarbMath.groupedByOverlappingAbsorptionTimes(input, defaultAbsorptionTime: TimeInterval(minutes: 180))

        XCTAssertEqual(output.count, grouped.count)

        for (expected, calculated) in zip(output, grouped) {
            XCTAssertEqual(expected, calculated)
        }
    }
}
