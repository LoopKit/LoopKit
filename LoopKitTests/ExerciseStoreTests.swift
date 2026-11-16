//
//  ExerciseStoreTests.swift
//  LoopKitTests
//
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit
@testable import LoopKit

class ExerciseStoreTests: XCTestCase {
    func testEmptyQueryAnchorRawValue() {
        XCTAssertTrue(ExerciseStore.QueryAnchor().rawValue.isEmpty)
        XCTAssertNil(ExerciseStore.QueryAnchor(rawValue: [:]))
    }

    func testEmptyHealthSampleQueryAnchorRawValue() {
        XCTAssertTrue(ExerciseStore.HealthSampleQueryAnchor().rawValue.isEmpty)
        XCTAssertEqual(ExerciseStore.HealthSampleQueryAnchor(rawValue: ["heartRate": [String: Any]()]), ExerciseStore.HealthSampleQueryAnchor())
    }

    func testHealthSampleUnits() {
        XCTAssertEqual(HKQuantity(unit: HKUnit(from: "ml/(kg*min)"), doubleValue: 42).doubleValue(for: StoredHealthSample.Kind.vo2Max.unit), 42, accuracy: 1e-9)
        XCTAssertEqual(HKQuantity(unit: .second(), doubleValue: 0.045).doubleValue(for: StoredHealthSample.Kind.heartRateVariabilitySDNN.unit), 45, accuracy: 1e-9)
        XCTAssertEqual(HKQuantity(unit: .count().unitDivided(by: .second()), doubleValue: 1).doubleValue(for: StoredHealthSample.Kind.heartRate.unit), 60, accuracy: 1e-9)
        XCTAssertEqual(HKQuantity(unit: .pound(), doubleValue: 1).doubleValue(for: StoredHealthSample.Kind.bodyMass.unit), 0.45359237, accuracy: 1e-9)
        for kind in StoredHealthSample.Kind.allCases {
            XCTAssertTrue(kind.quantityType.is(compatibleWith: kind.unit), kind.rawValue)
        }
    }

    func testMetadataValues() {
        XCTAssertEqual(StoredWorkout.MetadataValue(true as NSNumber), .bool(true))
        XCTAssertEqual(StoredWorkout.MetadataValue(9.5 as NSNumber), .number(9.5))
        XCTAssertEqual(StoredWorkout.MetadataValue("America/Chicago"), .string("America/Chicago"))
        XCTAssertEqual(StoredWorkout.MetadataValue(Date(timeIntervalSince1970: 0)), .string("1970-01-01T00:00:00.000Z"))
        XCTAssertEqual(StoredWorkout.MetadataValue(HKQuantity(unit: .meter(), doubleValue: 12)), .string("12 m"))
        XCTAssertNil(StoredWorkout.MetadataValue([1, 2]))
    }

    func testTimeZoneFromMetadata() {
        let workout = StoredWorkout(uuid: UUID(), startDate: Date(), endDate: Date(), duration: 0, activityType: .walking, source: StoredWorkout.Source(bundleIdentifier: "b", name: "n", operatingSystemVersion: "1.0.0"), metadata: [HKMetadataKeyTimeZone: .string("Europe/London")])
        XCTAssertEqual(workout.timeZone, TimeZone(identifier: "Europe/London"))
    }
}
