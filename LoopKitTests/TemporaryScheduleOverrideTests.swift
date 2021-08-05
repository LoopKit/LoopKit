//
//  TemporaryScheduleOverrideTests.swift
//  LoopKitTests
//
//  Created by Michael Pangburn on 1/2/19.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import XCTest
@testable import LoopKit

extension TimeZone {
    static var fixtureTimeZone: TimeZone {
        return TimeZone(secondsFromGMT: 25200)! // -0700
    }
    
    static var utcTimeZone: TimeZone {
        return TimeZone(secondsFromGMT: 0)!
    }
}

extension ISO8601DateFormatter {
    static func fixtureFormatter(timeZone: TimeZone = .fixtureTimeZone) -> Self {
        let formatter = self.init()

        formatter.formatOptions = .withInternetDateTime
        formatter.formatOptions.subtract(.withTimeZone)
        formatter.timeZone = timeZone

        return formatter
    }
}

class TemporaryScheduleOverrideTests: XCTestCase {

    let dateFormatter = ISO8601DateFormatter.localTimeDate()
    let epsilon = 1e-6

    let basalRateSchedule = BasalRateSchedule(dailyItems: [
        RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
        RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
        RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
    ])!

    private func date(at time: String) -> Date {
        return dateFormatter.date(from: "2019-01-01T\(time):00")!
    }

    private func basalUpOverride(start: String, end: String) -> TemporaryScheduleOverride {
        return TemporaryScheduleOverride(
            context: .custom,
            settings: TemporaryScheduleOverrideSettings(
                unit: .milligramsPerDeciliter,
                targetRange: nil,
                insulinNeedsScaleFactor: 1.5
            ),
            startDate: date(at: start),
            duration: .finite(date(at: end).timeIntervalSince(date(at: start))),
            enactTrigger: .local,
            syncIdentifier: UUID()
        )
    }

    private func applyingActiveBasalOverride(from start: String, to end: String, on schedule: BasalRateSchedule, referenceDate: Date? = nil) -> BasalRateSchedule {
        let override = basalUpOverride(start: start, end: end)
        let referenceDate = referenceDate ?? override.startDate
        return schedule.applyingBasalRateMultiplier(from: override, relativeTo: referenceDate)
    }

    // Override start aligns with schedule item start
    func testBasalRateScheduleOverrideStartTimeMatch() {
        let overrideBasalSchedule = applyingActiveBasalOverride(from: "00:00", to: "01:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(1), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overrideBasalSchedule.equals(expected, accuracy: epsilon))
    }

    // Override contained fully within a schedule item
    func testBasalRateScheduleOverrideContained() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "04:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(4), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    // Override end aligns with schedule item start
    func testBasalRateScheduleOverrideEndTimeMatch() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "06:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    // Override completely encapsulates schedule item
    func testBasalRateScheduleOverrideEncapsulate() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "22:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(2), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.5),
            RepeatingScheduleValue(startTime: .hours(22), value: 1.0),
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testSingleBasalRateSchedule() {
        let basalRateSchedule = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.0)
        ])!
        let overridden = applyingActiveBasalOverride(from: "08:00", to: "12:00", on: basalRateSchedule)
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.0),
            RepeatingScheduleValue(startTime: .hours(8), value: 1.5),
            RepeatingScheduleValue(startTime: .hours(12), value: 1.0)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testOverrideCrossingMidnight() {
        var override = basalUpOverride(start: "22:00", end: "23:00")
        override.duration += .hours(5) // override goes from 10pm to 4am of the next day

        let overridden = basalRateSchedule.applyingBasalRateMultiplier(from: override, relativeTo: date(at: "22:00"))
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(4), value: 1.2),
            RepeatingScheduleValue(startTime: .hours(6), value: 1.4),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.0),
            RepeatingScheduleValue(startTime: .hours(22), value: 1.5)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testMultiDayOverride() {
        var override = basalUpOverride(start: "02:00", end: "22:00")
        override.duration += .hours(48) // override goes from 2am until 10pm two days later

        let overridden = basalRateSchedule.applyingBasalRateMultiplier(
            from: override,
            relativeTo: date(at: "02:00") + .hours(24)
        )

        // expect full schedule override; start/end dates are too distant to have an effect
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.5)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testOutdatedOverride() {
        let overridden = applyingActiveBasalOverride(from: "02:00", to: "04:00", on: basalRateSchedule,
                                                     referenceDate: date(at: "12:00").addingTimeInterval(.hours(24)))
        let expected = basalRateSchedule

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testFarFutureOverride() {
        let overridden = applyingActiveBasalOverride(from: "10:00", to: "12:00", on: basalRateSchedule,
                                                     referenceDate: date(at: "02:00").addingTimeInterval(-.hours(24)))
        let expected = basalRateSchedule

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }

    func testIndefiniteOverride() {
        var override = basalUpOverride(start: "02:00", end: "22:00")
        override.duration = .indefinite
        let overridden = basalRateSchedule.applyingBasalRateMultiplier(from: override, relativeTo: date(at: "02:00"))

        // expect full schedule overridden
        let expected = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: .hours(0), value: 1.8),
            RepeatingScheduleValue(startTime: .hours(6), value: 2.1),
            RepeatingScheduleValue(startTime: .hours(20), value: 1.5)
        ])!

        XCTAssert(overridden.equals(expected, accuracy: epsilon))
    }
    
    func testDurationIsInfinite() {
        let tempOverride = TemporaryScheduleOverride(context: .legacyWorkout,
                                                     settings: .init(unit: .milligramsPerDeciliter, targetRange: DoubleRange(minValue: 120, maxValue: 150)),
                                                     startDate: Date(),
                                                     duration: .indefinite,
                                                     enactTrigger: .local,
                                                     syncIdentifier: UUID())
        XCTAssertTrue(tempOverride.duration.isInfinite)
    }

    func testOverrideScheduleAnnotatingReservoirSplitsDose() {
        let schedule = BasalRateSchedule(dailyItems: [
            RepeatingScheduleValue(startTime: 0, value: 0.225),
            RepeatingScheduleValue(startTime: 3600.0, value: 0.18000000000000002),
            RepeatingScheduleValue(startTime: 10800.0, value: 0.135),
            RepeatingScheduleValue(startTime: 12689.855275034904, value: 0.15),
            RepeatingScheduleValue(startTime: 21600.0, value: 0.2),
            RepeatingScheduleValue(startTime: 32400.0, value: 0.2),
            RepeatingScheduleValue(startTime: 50400.0, value: 0.2),
            RepeatingScheduleValue(startTime: 52403.79680299759, value: 0.16000000000000003),
            RepeatingScheduleValue(startTime: 63743.58014559746, value: 0.2),
            RepeatingScheduleValue(startTime: 63743.58014583588, value: 0.16000000000000003),
            RepeatingScheduleValue(startTime: 69968.05249071121, value: 0.2),
            RepeatingScheduleValue(startTime: 69968.05249094963, value: 0.18000000000000002),
            RepeatingScheduleValue(startTime: 79200.0, value: 0.225),
        ])!

        let dose = DoseEntry(
            type: .tempBasal,
            startDate: date(at: "19:25"),
            endDate: date(at: "19:30"),
            value: 0.8,
            unit: .units
        )

        let annotated = [dose].annotated(with: schedule)

        XCTAssertEqual(3, annotated.count)
        XCTAssertEqual(dose.programmedUnits, annotated.map { $0.unitsInDeliverableIncrements }.reduce(0, +))
    }

    // MARK: - Target range tests

    func testActiveTargetRangeOverride() {
        let overrideRange = DoubleRange(minValue: 120, maxValue: 140)
        let overrideStart = Date()
        let overrideDuration = TimeInterval(hours: 4)
        let settings = TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter, targetRange: overrideRange)
        let override = TemporaryScheduleOverride(context: .custom, settings: settings, startDate: overrideStart, duration: .finite(overrideDuration), enactTrigger: .local, syncIdentifier: UUID())
        let normalRange = DoubleRange(minValue: 95, maxValue: 105)
        let rangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: normalRange)])!.applyingOverride(override)

        XCTAssertEqual(rangeSchedule.value(at: overrideStart), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration / 2), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration + .hours(2)), overrideRange)
    }

    func testFutureTargetRangeOverride() {
        let overrideRange = DoubleRange(minValue: 120, maxValue: 140)
        let overrideStart = Date() + .hours(2)
        let overrideDuration = TimeInterval(hours: 4)
        let settings = TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter, targetRange: overrideRange)
        let futureOverride = TemporaryScheduleOverride(context: .custom, settings: settings, startDate: overrideStart, duration: .finite(overrideDuration), enactTrigger: .local, syncIdentifier: UUID())
        let normalRange = DoubleRange(minValue: 95, maxValue: 105)
        let rangeSchedule = GlucoseRangeSchedule(unit: .milligramsPerDeciliter, dailyItems: [RepeatingScheduleValue(startTime: 0, value: normalRange)])!.applyingOverride(futureOverride)

        XCTAssertEqual(rangeSchedule.value(at: overrideStart + .minutes(-5)), normalRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration), overrideRange)
        XCTAssertEqual(rangeSchedule.value(at: overrideStart + overrideDuration + .hours(2)), overrideRange)
    }
}

class TemporaryScheduleOverrideContextCodableTests: XCTestCase {
    func testCodablePreMeal() throws {
        try assertTemporaryScheduleOverrideContextCodable(.preMeal, encodesJSON: """
{
  "context" : "preMeal"
}
"""
        )
    }

    func testCodableLegacyWorkout() throws {
        try assertTemporaryScheduleOverrideContextCodable(.legacyWorkout, encodesJSON: """
{
  "context" : "legacyWorkout"
}
"""
        )
    }

    func testCodablePreset() throws {
        let preset = TemporaryScheduleOverridePreset(id: UUID(uuidString: "238E41EA-9576-4981-A1A4-51E10228584F")!,
                                                     symbol: "🚀",
                                                     name: "Rocket",
                                                     settings: TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                                                                 targetRange: DoubleRange(minValue: 90, maxValue: 100)),
                                                     duration: .indefinite)
        try assertTemporaryScheduleOverrideContextCodable(.preset(preset), encodesJSON: """
{
  "context" : {
    "preset" : {
      "preset" : {
        "duration" : "indefinite",
        "id" : "238E41EA-9576-4981-A1A4-51E10228584F",
        "name" : "Rocket",
        "settings" : {
          "targetRangeInMgdl" : {
            "maxValue" : 100,
            "minValue" : 90
          }
        },
        "symbol" : "🚀"
      }
    }
  }
}
"""
        )
    }

    func testCodableCustom() throws {
        try assertTemporaryScheduleOverrideContextCodable(.custom, encodesJSON: """
{
  "context" : "custom"
}
"""
        )
    }

    private func assertTemporaryScheduleOverrideContextCodable(_ original: TemporaryScheduleOverride.Context, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(context: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.context, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private struct TestContainer: Codable, Equatable {
        let context: TemporaryScheduleOverride.Context
    }
}

class TemporaryScheduleOverrideEnactTriggerCodableTests: XCTestCase {
    func testCodableLocal() throws {
        try assertTemporaryScheduleOverrideEnactTriggerCodable(.local, encodesJSON: """
{
  "enactTrigger" : "local"
}
"""
        )
    }

    func testCodableRemote() throws {
        try assertTemporaryScheduleOverrideEnactTriggerCodable(.remote("address"), encodesJSON: """
{
  "enactTrigger" : {
    "remote" : {
      "address" : "address"
    }
  }
}
"""
        )
    }

    private func assertTemporaryScheduleOverrideEnactTriggerCodable(_ original: TemporaryScheduleOverride.EnactTrigger, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(enactTrigger: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.enactTrigger, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private struct TestContainer: Codable, Equatable {
        let enactTrigger: TemporaryScheduleOverride.EnactTrigger
    }
}

class TemporaryScheduleOverrideDurationCodableTests: XCTestCase {
    func testCodableFinite() throws {
        try assertTemporaryScheduleOverrideDurationCodable(.finite(.hours(2.5)), encodesJSON: """
{
  "duration" : {
    "finite" : {
      "duration" : 9000
    }
  }
}
"""
        )
    }

    func testCodableIndefinite() throws {
        try assertTemporaryScheduleOverrideDurationCodable(.indefinite, encodesJSON: """
{
  "duration" : "indefinite"
}
"""
        )
    }

    private func assertTemporaryScheduleOverrideDurationCodable(_ original: TemporaryScheduleOverride.Duration, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(duration: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.duration, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private struct TestContainer: Codable, Equatable {
        let duration: TemporaryScheduleOverride.Duration
    }
}

private extension TemporaryScheduleOverride.Duration {
    static func += (lhs: inout TemporaryScheduleOverride.Duration, rhs: TimeInterval) {
        switch lhs {
        case .finite(let interval):
            lhs = .finite(interval + rhs)
        case .indefinite:
            return
        }
    }
}

class TemporaryOverrideEndCodableTests: XCTestCase {
    var dateFormatter = ISO8601DateFormatter.fixtureFormatter()
    
    private func date(at time: String) -> Date {
        return dateFormatter.date(from: "2019-01-01T\(time):00")!
    }
    
    func testCodableOverrideEarlyEnd() throws {
        let end = End.early(date(at: "02:00"))
        try assertEndCodable(end, encodesJSON: """
{
  "end" : {
    "date" : 567975600,
    "type" : "early"
  }
}
"""
        )
    }
    
    func testCodableOverrideNaturalEnd() throws {
        let end = End.natural
        try assertEndCodable(end, encodesJSON: """
{
  "end" : {
    "type" : "natural"
  }
}
"""
        )
    }
    
    func testCodableOverrideDeleted() throws {
        let end = End.deleted
        try assertEndCodable(end, encodesJSON: """
{
  "end" : {
    "type" : "deleted"
  }
}
"""
        )
    }
    
    private func assertEndCodable(_ original: End, encodesJSON string: String) throws {
        let data = try encoder.encode(TestContainer(end: original))
        XCTAssertEqual(String(data: data, encoding: .utf8), string)
        let decoded = try decoder.decode(TestContainer.self, from: data)
        XCTAssertEqual(decoded.end, original)
    }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    private let decoder = JSONDecoder()

    private struct TestContainer: Codable, Equatable {
        let end: End
    }
}
