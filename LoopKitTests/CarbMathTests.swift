//
//  CarbMathTests.swift
//  CarbKitTests
//
//  Created by Nathan Racklyeft on 1/18/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import XCTest
@testable import LoopKit
import HealthKit


class CarbMathTests: XCTestCase {

    private func printCarbValues(_ carbValues: [CarbValue]) {
        let unit = HKUnit.gram()

        print("\n\n")
        print(String(data: try! JSONSerialization.data(
            withJSONObject: carbValues.map({ (value) -> [String: Any] in
                return [
                    "date": ISO8601DateFormatter.localTimeDate().string(from: value.startDate),
                    "amount": value.quantity.doubleValue(for: unit),
                    "unit": "g"
                ]
            }),
            options: .prettyPrinted), encoding: .utf8)!)
        print("\n\n")
    }

    private func loadSchedules() -> (CarbRatioSchedule, InsulinSensitivitySchedule) {
        let fixture: JSONDictionary = loadFixture("read_carb_ratios")
        let schedule = fixture["schedule"] as! [JSONDictionary]

        let items = schedule.map {
            return RepeatingScheduleValue(startTime: TimeInterval(minutes: $0["offset"] as! Double), value: $0["ratio"] as! Double)
        }

        return (
            CarbRatioSchedule(unit: HKUnit.gram(), dailyItems: items)!,
            InsulinSensitivitySchedule(unit: HKUnit.milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0.0, value: 40.0)])!
        )
    }

    private func loadHistoryFixture(_ name: String) -> [NewCarbEntry] {
        let fixture: [JSONDictionary] = loadFixture(name)
        return carbEntriesFromFixture(fixture)
    }
    
    private func loadCarbEntryFixture() -> [NewCarbEntry] {
        let fixture: [JSONDictionary] = loadFixture("carb_entry_input")
        return carbEntriesFromFixture(fixture)
    }

    private func carbEntriesFromFixture(_ fixture: [JSONDictionary]) -> [NewCarbEntry] {
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            let absorptionTime: TimeInterval?
            if let absorptionTimeMinutes = $0["absorption_time"] as? Double {
                absorptionTime = TimeInterval(minutes: absorptionTimeMinutes)
            } else {
                absorptionTime = nil
            }
            return NewCarbEntry(
                quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue: $0["amount"] as! Double),
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                foodType: nil,
                absorptionTime: absorptionTime
            )
        }
    }

    private func loadEffectOutputFixture() -> [GlucoseEffect] {
        let fixture: [JSONDictionary] = loadFixture("carb_effect_from_history_output")
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return GlucoseEffect(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    private func loadCOBOutputFixture(_ name: String) -> [CarbValue] {
        let fixture: [JSONDictionary] = loadFixture(name)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()

        return fixture.map {
            return CarbValue(startDate: dateFormatter.date(from: $0["date"] as! String)!, quantity: HKQuantity(unit: HKUnit(from: $0["unit"] as! String), doubleValue:$0["amount"] as! Double))
        }
    }

    private func loadICEInputFixture(_ name: String) -> [GlucoseEffectVelocity] {
        let fixture: [JSONDictionary] = loadFixture(name)
        let dateFormatter = ISO8601DateFormatter.localTimeDate()
        
        let unit = HKUnit.milligramsPerDeciliter.unitDivided(by: .minute())
        
        return fixture.map {
            let quantity = HKQuantity(unit: unit, doubleValue: $0["velocity"] as! Double)
            return GlucoseEffectVelocity(
                startDate: dateFormatter.date(from: $0["start_at"] as! String)!,
                endDate: dateFormatter.date(from: $0["end_at"] as! String)!,
                quantity: quantity)
        }
    }
    
    func testCarbEffectWithZeroEntry() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        
        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        let carbEntry = NewCarbEntry(
            quantity: HKQuantity(unit: HKUnit.gram(), doubleValue: 0),
            startDate: inputICE[0].startDate,
            foodType: nil,
            absorptionTime: TimeInterval(minutes: 120)
        )
        
        let statuses = [carbEntry].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: defaultAbsorptionTimes.slow / defaultAbsorptionTimes.medium,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: 1.5,
            absorptionModel: LinearAbsorption(),
            adaptiveAbsorptionRateEnabled: false,
            adaptiveRateStandbyIntervalFraction: 0.2
        )
        
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses[0].absorption?.estimatedTimeRemaining, 0)
    }

    func testCarbEffectFromHistory() {
        let input = loadHistoryFixture("carb_effect_from_history_input")
        let output = loadEffectOutputFixture()
        let (carbRatios, insulinSensitivities) = loadSchedules()
        
        let effects = input.glucoseEffects(carbRatios: carbRatios, insulinSensitivities: insulinSensitivities, defaultAbsorptionTime: TimeInterval(minutes: 180), absorptionModel: ParabolicAbsorption())

        XCTAssertEqual(output.count, effects.count)

        for (expected, calculated) in zip(output, effects) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), calculated.quantity.doubleValue(for: HKUnit.milligramsPerDeciliter), accuracy: Double(Float.ulpOfOne))
        }
    }

    func testCarbsOnBoardFromHistory() {
        let input = loadHistoryFixture("carb_effect_from_history_input")
        let output = loadCOBOutputFixture("carbs_on_board_output")
        
        //CarbAbsorptionModel.settings = CarbModelSettings(absorptionModel: ParabolicAbsorption(), initialAbsorptionTimeOverrun: 1.5, adaptiveAbsorptionRateEnabled: false)

        let cob = input.carbsOnBoard(defaultAbsorptionTime: TimeInterval(minutes: 180), absorptionModel: ParabolicAbsorption(), delay: TimeInterval(minutes: 10), delta: TimeInterval(minutes: 5))

        XCTAssertEqual(output.count, cob.count)

        for (expected, calculated) in zip(output, cob) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }
    }
    
    func testDynamicAbsorptionNoneObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_none_output")

        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        let futureCarbEntry = carbEntries[2]
        
        let statuses = [futureCarbEntry].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: defaultAbsorptionTimes.slow / defaultAbsorptionTimes.medium,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: defaultAbsorptionTimes.slow / defaultAbsorptionTimes.medium,
            absorptionModel: LinearAbsorption(),
            adaptiveAbsorptionRateEnabled: false,
            adaptiveRateStandbyIntervalFraction: 0.2
        )
        
        XCTAssertEqual(statuses.count, 1)
        
        // Full absorption remains
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, TimeInterval(hours: 4), accuracy: 1)
        
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            absorptionModel: LinearAbsorption(),
            delay: TimeInterval(minutes: 10),
            delta: TimeInterval(minutes: 5))

        let unit = HKUnit.gram()

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }
    
    func testDynamicAbsorptionPartiallyObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_partial_output")

        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: defaultAbsorptionTimes.slow / defaultAbsorptionTimes.medium,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: defaultAbsorptionTimes.slow / defaultAbsorptionTimes.medium,
            absorptionModel: LinearAbsorption(),
            adaptiveAbsorptionRateEnabled: false,
            adaptiveRateStandbyIntervalFraction: 0.2)
        
        XCTAssertEqual(statuses.count, 1)
        
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 8509, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = HKUnit.gram()

        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 18, accuracy: Double(Float.ulpOfOne))
        
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            absorptionModel: LinearAbsorption(),
            delay: TimeInterval(minutes: 10),
            delta: TimeInterval(minutes: 5)
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[25].quantity.doubleValue(for: unit), 9, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }
    
    
    func testDynamicAbsorptionFullyObserved() {
        let inputICE = loadICEInputFixture("ice_1_hour_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_1_hour_output")

        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: defaultAbsorptionTimes.slow / defaultAbsorptionTimes.medium,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: defaultAbsorptionTimes.slow / defaultAbsorptionTimes.medium,
            absorptionModel: LinearAbsorption(),
            adaptiveAbsorptionRateEnabled: false,
            adaptiveRateStandbyIntervalFraction: 0.2
        )
        
        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)
        
        // No remaining absorption
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 0, accuracy: 1)
        
        let absorption = statuses[0].absorption!
        let unit = HKUnit.gram()
        
        // All should be absorbed
        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 44, accuracy: 1)
        
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            absorptionModel: LinearAbsorption(),
            delay: TimeInterval(minutes: 10),
            delta: TimeInterval(minutes: 5)
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard[0].quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[1].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[10].quantity.doubleValue(for: unit), 21, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[17].quantity.doubleValue(for: unit), 7, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[18].quantity.doubleValue(for: unit), 4, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[30].quantity.doubleValue(for: unit), 0, accuracy: 1)
    }
    
    func testDynamicAbsorptionNeverFullyObserved() {
        let inputICE = loadICEInputFixture("ice_slow_absorption")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_slow_absorption_output")

        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        let statuses = [carbEntries[1]].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: defaultAbsorptionTimes.slow / defaultAbsorptionTimes.medium,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: defaultAbsorptionTimes.slow / defaultAbsorptionTimes.medium,
            absorptionModel: LinearAbsorption(),
            adaptiveAbsorptionRateEnabled: false,
            adaptiveRateStandbyIntervalFraction: 0.2)
        
        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)
        
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 10488, accuracy: 1)
        
        // Check 12 hours later
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 18)),
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            absorptionModel: LinearAbsorption(),
            delay: TimeInterval(minutes: 10),
            delta: TimeInterval(minutes: 5)
        )

        let unit = HKUnit.gram()

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[5].quantity.doubleValue(for: unit), 30, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testGroupedByOverlappingAbsorptionTimeFromHistory() {
        let input = loadHistoryFixture("grouped_by_overlapping_absorption_times_input")
        let outputFixture: [[JSONDictionary]] = loadFixture("grouped_by_overlapping_absorption_times_output")
        let output = outputFixture.map { self.carbEntriesFromFixture($0) }
        let grouped = input.groupedByOverlappingAbsorptionTimes(defaultAbsorptionTime: TimeInterval(minutes: 180))

        XCTAssertEqual(output.count, grouped.count)

        for (expected, calculated) in zip(output, grouped) {
            XCTAssertEqual(expected, calculated)
        }
    }

    func testGroupedByOverlappingAbsorptionTimeEdgeCases() {
        let input = loadHistoryFixture("grouped_by_overlapping_absorption_times_border_case_input")
        let outputFixture: [[JSONDictionary]] = loadFixture("grouped_by_overlapping_absorption_times_border_case_output")
        let output = outputFixture.map { self.carbEntriesFromFixture($0) }
        let grouped = input.groupedByOverlappingAbsorptionTimes(defaultAbsorptionTime: TimeInterval(minutes: 180))

        XCTAssertEqual(output.count, grouped.count)

        for (expected, calculated) in zip(output, grouped) {
            XCTAssertEqual(expected, calculated)
        }
    }
    
    // Aditional tests for nonlinear and adaptive-rate carb absorption models
    
    func testDynamicAbsorptionPiecewiseLinearNoneObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_none_piecewiselinear_output")

        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        let futureCarbEntry = carbEntries[2]
        
        let statuses = [futureCarbEntry].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: 1.5,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: 1.5,
            absorptionModel: PiecewiseLinearAbsorption(),
            adaptiveAbsorptionRateEnabled: false,
            adaptiveRateStandbyIntervalFraction: 0.2
        )
        
        XCTAssertEqual(statuses.count, 1)
        
        // Full absorption remains
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, TimeInterval(hours: 3), accuracy: 1)
        
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            absorptionModel: PiecewiseLinearAbsorption(),
            delay: TimeInterval(minutes: 10),
            delta: TimeInterval(minutes: 5))

        let unit = HKUnit.gram()

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicAbsorptionPiecewiseLinearPartiallyObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_partial_piecewiselinear_output")

        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: 1.5,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: 1.5,
            absorptionModel: PiecewiseLinearAbsorption(),
            adaptiveAbsorptionRateEnabled: false,
            adaptiveRateStandbyIntervalFraction: 0.2)
        
        XCTAssertEqual(statuses.count, 1)
        
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 7008, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = HKUnit.gram()

        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 18, accuracy: Double(Float.ulpOfOne))
        
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            absorptionModel: PiecewiseLinearAbsorption(),
            delay: TimeInterval(minutes: 10),
            delta: TimeInterval(minutes: 5)
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[20].quantity.doubleValue(for: unit), 5, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicAbsorptionPiecewiseLinearFullyObserved() {
        let inputICE = loadICEInputFixture("ice_1_hour_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_1_hour_output")

        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        //CarbAbsorptionModel.settings = CarbModelSettings(absorptionModel: PiecewiseLinearAbsorption(), initialAbsorptionTimeOverrun: 1.5, adaptiveAbsorptionRateEnabled: false)
        
        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: 1.5,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: 1.5,
            absorptionModel: PiecewiseLinearAbsorption(),
            adaptiveAbsorptionRateEnabled: false,
            adaptiveRateStandbyIntervalFraction: 0.2
        )
        
        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)
        
        // No remaining absorption
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 0, accuracy: 1)
        
        let absorption = statuses[0].absorption!
        let unit = HKUnit.gram()
        
        // All should be absorbed
        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 44, accuracy: 1)
        
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            absorptionModel: PiecewiseLinearAbsorption(),
            delay: TimeInterval(minutes: 10),
            delta: TimeInterval(minutes: 5)
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard[0].quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[1].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[10].quantity.doubleValue(for: unit), 21, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[17].quantity.doubleValue(for: unit), 7, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[18].quantity.doubleValue(for: unit), 4, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[30].quantity.doubleValue(for: unit), 0, accuracy: 1)
    }

    func testDynamicAbsorptionPiecewiseLinearNeverFullyObserved() {
        let inputICE = loadICEInputFixture("ice_slow_absorption")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_slow_absorption_piecewiselinear_output")

        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        let statuses = [carbEntries[1]].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: 1.5,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: 1.5,
            absorptionModel: PiecewiseLinearAbsorption(),
            adaptiveAbsorptionRateEnabled: false,
            adaptiveRateStandbyIntervalFraction: 0.2)
        
        XCTAssertEqual(statuses.count, 1)
        XCTAssertNotNil(statuses[0].absorption)
        
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 6888, accuracy: 1)
        
        // Check 12 hours later
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 18)),
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            absorptionModel: PiecewiseLinearAbsorption(),
            delay: TimeInterval(minutes: 10),
            delta: TimeInterval(minutes: 5)
        )

        let unit = HKUnit.gram()

        XCTAssertEqual(output.count, carbsOnBoard.count)
        
        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[5].quantity.doubleValue(for: unit), 30, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }
    
    func testDynamicAbsorptionPiecewiseLinearAdaptiveRatePartiallyObserved() {
        let inputICE = loadICEInputFixture("ice_35_min_input")
        let carbEntries = loadCarbEntryFixture()
        let output = loadCOBOutputFixture("ice_35_min_partial_piecewiselinear_adaptiverate_output")

        let (carbRatios, insulinSensitivities) = loadSchedules()
        let defaultAbsorptionTimes = CarbStore.DefaultAbsorptionTimes(
            fast: TimeInterval(hours: 1),
            medium: TimeInterval(hours: 2),
            slow: TimeInterval(hours: 4)
        )
        
        let statuses = [carbEntries[0]].map(
            to: inputICE,
            carbRatio: carbRatios,
            insulinSensitivity: insulinSensitivities,
            absorptionTimeOverrun: 1.5,
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            delay: TimeInterval(minutes: 0),
            initialAbsorptionTimeOverrun: 1.0,
            absorptionModel: PiecewiseLinearAbsorption(),
            adaptiveAbsorptionRateEnabled: true,
            adaptiveRateStandbyIntervalFraction: 0.2)
        
        XCTAssertEqual(statuses.count, 1)
        
        XCTAssertEqual(statuses[0].absorption!.estimatedTimeRemaining, 3326, accuracy: 1)

        let absorption = statuses[0].absorption!
        let unit = HKUnit.gram()

        XCTAssertEqual(absorption.observed.doubleValue(for: unit), 18, accuracy: Double(Float.ulpOfOne))
        
        let carbsOnBoard = statuses.dynamicCarbsOnBoard(
            from: inputICE[0].startDate,
            to: inputICE[0].startDate.addingTimeInterval(TimeInterval(hours: 6)),
            defaultAbsorptionTime: defaultAbsorptionTimes.medium,
            absorptionModel: PiecewiseLinearAbsorption(),
            delay: TimeInterval(minutes: 10),
            delta: TimeInterval(minutes: 5)
        )

        XCTAssertEqual(output.count, carbsOnBoard.count)

        for (expected, calculated) in zip(output, carbsOnBoard) {
            XCTAssertEqual(expected.startDate, calculated.startDate)
            XCTAssertEqual(expected.quantity.doubleValue(for: HKUnit.gram()), calculated.quantity.doubleValue(for: HKUnit.gram()), accuracy: Double(Float.ulpOfOne))
        }

        XCTAssertEqual(carbsOnBoard.first!.quantity.doubleValue(for: unit), 0, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[2].quantity.doubleValue(for: unit), 44, accuracy: 1)
        XCTAssertEqual(carbsOnBoard[10].quantity.doubleValue(for: unit), 15, accuracy: 1)
        XCTAssertEqual(carbsOnBoard.last!.quantity.doubleValue(for: unit), 0, accuracy: 1)
    }
}
