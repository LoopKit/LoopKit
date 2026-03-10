//
//  TemporaryPresetScheduleTests.swift
//  LoopKit
//
//  Created by Pete Schwamb on 6/16/25.
//  Copyright © 2025 LoopKit Authors. All rights reserved.
//


import XCTest
import Foundation
import LoopAlgorithm
@testable import LoopKit


class TemporaryPresetScheduleTests: XCTestCase {

    var calendar: Calendar!
    var timeZone: TimeZone!

    override func setUp() {
        super.setUp()
        // Use a fixed timezone and calendar for consistent testing
        timeZone = TimeZone(identifier: "America/New_York")!
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
    }

    // MARK: - Helper Methods

    private func createDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = timeZone
        return calendar.date(from: components)!
    }

    private func createPreset(
        scheduleStartDate: Date?,
        repeatOptions: PresetScheduleRepeatOptions = .none
    ) -> TemporaryPreset {
        return TemporaryPreset(
            symbol: "🎯",
            name: "Test Preset",
            settings: TemporaryPresetSettings(unit: .milligramsPerDeciliter, targetRange: DoubleRange(minValue: 100, maxValue: 115)),
            duration: .finite(TimeInterval(3600)),
            // 1 hour
            scheduleStartDate: scheduleStartDate,
            repeatOptions: repeatOptions
        )
    }

    // MARK: - Tests for No Schedule Date

    func testNextScheduledStartAfter_NoScheduleDate_ReturnsNil() {
        let preset = createPreset(scheduleStartDate: nil)
        let testDate = createDate(year: 2024, month: 1, day: 15, hour: 10)

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)

        XCTAssertNil(result)
    }

    // MARK: - Tests for One-Time Presets (No Repeat Options)

    func testNextScheduledStartAfter_OneTimePreset_FutureDate_ReturnsScheduleDate() {
        let scheduleDate = createDate(year: 2024, month: 1, day: 20, hour: 14, minute: 30)
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .none)
        let testDate = createDate(year: 2024, month: 1, day: 15, hour: 10)

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)

        XCTAssertEqual(result, scheduleDate)
    }

    func testNextScheduledStartAfter_OneTimePreset_PastDate_ReturnsNil() {
        let scheduleDate = createDate(year: 2024, month: 1, day: 10, hour: 14, minute: 30)
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .none)
        let testDate = createDate(year: 2024, month: 1, day: 15, hour: 10)

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)

        XCTAssertNil(result)
    }

    func testNextScheduledStartAfter_OneTimePreset_SameDate_ReturnsNil() {
        let scheduleDate = createDate(year: 2024, month: 1, day: 15, hour: 14, minute: 30)
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .none)
        let testDate = scheduleDate

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)

        XCTAssertNil(result)
    }

    // MARK: - Tests for Single Day Repeating Presets

    func testNextScheduledStartAfter_MondayRepeat_FromSunday_ReturnsNextMonday() {
        // Schedule start date is a Monday at 9:00 AM
        let scheduleDate = createDate(year: 2024, month: 1, day: 15, hour: 9) // Monday
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .monday)

        // Test from Sunday before
        let testDate = createDate(year: 2024, month: 1, day: 14, hour: 10) // Sunday

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 1, day: 15, hour: 9) // Next Monday at 9:00 AM

        XCTAssertEqual(result, expected)
    }

    func testNextScheduledStartAfter_MondayRepeat_FromMonday_ReturnsFollowingMonday() {
        // Schedule start date is a Monday at 9:00 AM
        let scheduleDate = createDate(year: 2024, month: 1, day: 15, hour: 9) // Monday
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .monday)

        // Test from the same Monday but later in the day
        let testDate = createDate(year: 2024, month: 1, day: 15, hour: 10) // Same Monday

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 1, day: 22, hour: 9) // Following Monday at 9:00 AM

        XCTAssertEqual(result, expected)
    }

    func testNextScheduledStartAfter_FridayRepeat_PreservesTime() {
        // Schedule start date is a Friday at 2:30:45 PM
        let scheduleDate = createDate(year: 2024, month: 1, day: 12, hour: 14, minute: 30, second: 45) // Friday
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .friday)

        // Test from Thursday
        let testDate = createDate(year: 2024, month: 1, day: 11, hour: 10) // Thursday

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 1, day: 12, hour: 14, minute: 30, second: 45) // Next Friday with exact time

        XCTAssertEqual(result, expected)
    }

    // MARK: - Tests for Multiple Day Repeating Presets

    func testNextScheduledStartAfter_WeekdaysRepeat_FromSunday_ReturnsMonday() {
        // Schedule start date is a Monday at 8:00 AM
        let scheduleDate = createDate(year: 2024, month: 1, day: 15, hour: 8) // Monday
        let weekdays: PresetScheduleRepeatOptions = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: weekdays)

        // Test from Sunday
        let testDate = createDate(year: 2024, month: 1, day: 14, hour: 10) // Sunday

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 1, day: 15, hour: 8) // Monday at 8:00 AM

        XCTAssertEqual(result, expected)
    }

    func testNextScheduledStartAfter_WeekdaysRepeat_FromWednesday_ReturnsThursday() {
        // Schedule start date is a Monday at 8:00 AM
        let scheduleDate = createDate(year: 2024, month: 1, day: 15, hour: 8) // Monday
        let weekdays: PresetScheduleRepeatOptions = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: weekdays)

        // Test from Wednesday afternoon
        let testDate = createDate(year: 2024, month: 1, day: 17, hour: 15) // Wednesday

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 1, day: 18, hour: 8) // Thursday at 8:00 AM

        XCTAssertEqual(result, expected)
    }

    func testNextScheduledStartAfter_WeekendsRepeat_FromFriday_ReturnsSaturday() {
        // Schedule start date is a Saturday at 10:00 AM
        let scheduleDate = createDate(year: 2024, month: 1, day: 13, hour: 10) // Saturday
        let weekends: PresetScheduleRepeatOptions = [.saturday, .sunday]
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: weekends)

        // Test from Friday
        let testDate = createDate(year: 2024, month: 1, day: 12, hour: 15) // Friday

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 1, day: 13, hour: 10) // Saturday at 10:00 AM

        XCTAssertEqual(result, expected)
    }

    // MARK: - Edge Cases

    func testNextScheduledStartAfter_EndOfWeek_WrapToNextWeek() {
        // Schedule start date is a Wednesday at 9:00 AM
        let scheduleDate = createDate(year: 2024, month: 1, day: 17, hour: 9) // Wednesday
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .wednesday)

        // Test from Saturday (end of week)
        let testDate = createDate(year: 2024, month: 1, day: 20, hour: 10) // Saturday

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 1, day: 24, hour: 9) // Next Wednesday at 9:00 AM

        XCTAssertEqual(result, expected)
    }

    func testNextScheduledStartAfter_MonthBoundary() {
        // Schedule start date is a Monday in January
        let scheduleDate = createDate(year: 2024, month: 1, day: 29, hour: 9) // Monday, Jan 29
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .monday)

        // Test from Wednesday, Jan 31
        let testDate = createDate(year: 2024, month: 1, day: 31, hour: 10) // Wednesday, Jan 31

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 2, day: 5, hour: 9) // Monday, Feb 5 at 9:00 AM

        XCTAssertEqual(result, expected)
    }

    func testNextScheduledStartAfter_LeapYear() {
        // Test around leap day
        let scheduleDate = createDate(year: 2024, month: 2, day: 28, hour: 9) // Wednesday, Feb 28 (leap year)
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .thursday)

        // Test from Wednesday, Feb 28
        let testDate = createDate(year: 2024, month: 2, day: 28, hour: 15) // Same Wednesday

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 2, day: 29, hour: 9) // Thursday, Feb 29 (leap day) at 9:00 AM

        XCTAssertEqual(result, expected)
    }

    // MARK: - Tests for All Days of Week

    func testNextScheduledStartAfter_AllDaysOfWeek() {
        let scheduleDate = createDate(year: 2024, month: 1, day: 15, hour: 12) // Monday
        let allDays: PresetScheduleRepeatOptions = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: allDays)

        // Test from Monday afternoon - should return next day (Tuesday)
        let testDate = createDate(year: 2024, month: 1, day: 15, hour: 15) // Monday

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 1, day: 16, hour: 12) // Tuesday at 12:00 PM

        XCTAssertEqual(result, expected)
    }

    // MARK: - Boundary Time Tests

    func testNextScheduledStartAfter_ExactTime_ReturnsNow() {
        // Schedule start date is a Monday at 9:00 AM
        let scheduleDate = createDate(year: 2024, month: 1, day: 15, hour: 9) // Monday
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .monday)

        // Test from the exact same time on the same Monday
        let testDate = createDate(year: 2024, month: 1, day: 15, hour: 9) // Same Monday, same time

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)

        XCTAssertEqual(result, scheduleDate)
    }

    func testNextScheduledStartAfter_OneSecondBefore_ReturnsSameDay() {
        // Schedule start date is a Monday at 9:00:00 AM
        let scheduleDate = createDate(year: 2024, month: 1, day: 15, hour: 9, minute: 0, second: 0) // Monday
        let preset = createPreset(scheduleStartDate: scheduleDate, repeatOptions: .monday)

        // Test from one second before on the same Monday
        let testDate = createDate(year: 2024, month: 1, day: 15, hour: 8, minute: 59, second: 59) // Same Monday, one second before

        let result = preset.nextScheduledStartAfter(testDate, calendar: calendar)
        let expected = createDate(year: 2024, month: 1, day: 15, hour: 9, minute: 0, second: 0) // Same Monday at 9:00:00 AM

        XCTAssertEqual(result, expected)
    }
}
