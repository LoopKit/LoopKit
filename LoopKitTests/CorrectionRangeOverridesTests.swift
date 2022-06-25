//
//  CorrectionRangeOverridesTests.swift
//  LoopKitTests
//
//  Created by Nathaniel Hamming on 2021-03-12.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import XCTest
import HealthKit

@testable import LoopKit

class CorrectionRangeOverridesTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testInitializerDouble() throws {
        let unit = HKUnit.milligramsPerDeciliter
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 75, maxValue: 90),
            workout: DoubleRange(minValue: 80, maxValue: 100),
            unit: unit)

        var expectedRanges: [CorrectionRangeOverrides.Preset: ClosedRange<HKQuantity>] = [:]
        expectedRanges[.preMeal] = DoubleRange(minValue: 75, maxValue: 90).quantityRange(for: unit)
        expectedRanges[.workout] = DoubleRange(minValue: 80, maxValue: 100).quantityRange(for: unit)

        XCTAssertEqual(correctionRangeOverrides.ranges, expectedRanges)
        XCTAssertEqual(correctionRangeOverrides.preMeal, expectedRanges[.preMeal])
        XCTAssertEqual(correctionRangeOverrides.workout, expectedRanges[.workout])
    }

    func testInitializerGlucoseRange() throws {
        let unit = HKUnit.milligramsPerDeciliter
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: GlucoseRange(minValue: 75, maxValue: 90, unit: unit),
            workout: GlucoseRange(minValue: 80, maxValue: 100, unit: unit))

        var expectedRanges: [CorrectionRangeOverrides.Preset: ClosedRange<HKQuantity>] = [:]
        expectedRanges[.preMeal] = DoubleRange(minValue: 75, maxValue: 90).quantityRange(for: unit)
        expectedRanges[.workout] = DoubleRange(minValue: 80, maxValue: 100).quantityRange(for: unit)

        XCTAssertEqual(correctionRangeOverrides.ranges, expectedRanges)
        XCTAssertEqual(correctionRangeOverrides.preMeal, expectedRanges[.preMeal])
        XCTAssertEqual(correctionRangeOverrides.workout, expectedRanges[.workout])
    }

    func testInitializerQuantity() throws {
        let unit = HKUnit.millimolesPerLiter
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 4.0, maxValue: 5.0).quantityRange(for: unit),
            workout: DoubleRange(minValue: 4.5, maxValue: 6.0).quantityRange(for: unit))

        var expectedRanges: [CorrectionRangeOverrides.Preset: ClosedRange<HKQuantity>] = [:]
        expectedRanges[.preMeal] = DoubleRange(minValue: 4.0, maxValue: 5.0).quantityRange(for: unit)
        expectedRanges[.workout] = DoubleRange(minValue: 4.5, maxValue: 6.0).quantityRange(for: unit)

        XCTAssertEqual(correctionRangeOverrides.ranges, expectedRanges)
        XCTAssertEqual(correctionRangeOverrides.preMeal, expectedRanges[.preMeal])
        XCTAssertEqual(correctionRangeOverrides.workout, expectedRanges[.workout])
    }

    func testPresetTitle() throws {
        XCTAssertEqual(CorrectionRangeOverrides.Preset.preMeal.title, "Pre-Meal")
        XCTAssertEqual(CorrectionRangeOverrides.Preset.workout.title, "Workout")
    }

    func testPresetTherapySettings() throws {
        XCTAssertEqual(CorrectionRangeOverrides.Preset.preMeal.therapySetting, .preMealCorrectionRangeOverride)
        XCTAssertEqual(CorrectionRangeOverrides.Preset.workout.therapySetting, .workoutCorrectionRangeOverride)
    }

    let encodedString = """
    {
      "preMealRange" : {
        "bloodGlucoseUnit" : "mg/dL",
        "range" : {
          "maxValue" : 90,
          "minValue" : 75
        }
      },
      "workoutRange" : {
        "bloodGlucoseUnit" : "mg/dL",
        "range" : {
          "maxValue" : 100,
          "minValue" : 80
        }
      }
    }
    """

    func testEncoding() throws {
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 75, maxValue: 90),
            workout: DoubleRange(minValue: 80, maxValue: 100),
            unit: .milligramsPerDeciliter)
        let data = try encoder.encode(correctionRangeOverrides)
        XCTAssertEqual(encodedString, String(data: data, encoding: .utf8)!)
    }

    func testDecoding() throws {
        let data = encodedString.data(using: .utf8)!
        let decoded = try decoder.decode(CorrectionRangeOverrides.self, from: data)
        let expected = CorrectionRangeOverrides(
            preMeal: DoubleRange(minValue: 75, maxValue: 90),
            workout: DoubleRange(minValue: 80, maxValue: 100),
            unit: .milligramsPerDeciliter)

        XCTAssertEqual(expected, decoded)
        XCTAssertEqual(decoded.ranges, expected.ranges)
    }

    func testRawValue() throws {
        let unit = HKUnit.milligramsPerDeciliter
        let preMealDoubleRange = DoubleRange(minValue: 75, maxValue: 90)
        let workoutDoubleRange = DoubleRange(minValue: 80, maxValue: 100)
        let correctionRangeOverrides = CorrectionRangeOverrides(
            preMeal: preMealDoubleRange,
            workout: workoutDoubleRange,
            unit: unit)
        var expectedRawValue: [String:Any] = [:]
        expectedRawValue["preMealTargetRange"] = GlucoseRange(range: preMealDoubleRange, unit: unit).rawValue
        expectedRawValue["workoutTargetRange"] = GlucoseRange(range: workoutDoubleRange, unit: unit).rawValue

        let preMealTargetRange = GlucoseRange(rawValue: correctionRangeOverrides.rawValue["preMealTargetRange"] as! GlucoseRange.RawValue)
        let expectedPreMealTargetRange = GlucoseRange(rawValue: expectedRawValue["preMealTargetRange"] as! GlucoseRange.RawValue)
        XCTAssertEqual(preMealTargetRange, expectedPreMealTargetRange)

        let workoutTargetRange = GlucoseRange(rawValue: correctionRangeOverrides.rawValue["workoutTargetRange"] as! GlucoseRange.RawValue)
        let expectedWorkoutTargetRange = GlucoseRange(rawValue: expectedRawValue["workoutTargetRange"] as! GlucoseRange.RawValue)
        XCTAssertEqual(workoutTargetRange, expectedWorkoutTargetRange)
    }

    func testInitializeFromRawValue() throws {
        let unit = HKUnit.milligramsPerDeciliter
        var rawValue: [String:Any] = [:]
        rawValue["preMealTargetRange"] = GlucoseRange(minValue: 80, maxValue: 100, unit: unit).rawValue
        rawValue["workoutTargetRange"] = GlucoseRange(minValue: 110, maxValue: 130, unit: unit).rawValue

        let correctionRangeOverrides = CorrectionRangeOverrides(rawValue: rawValue)
        var expectedRanges: [CorrectionRangeOverrides.Preset: ClosedRange<HKQuantity>] = [:]
        expectedRanges[.preMeal] = DoubleRange(minValue: 80, maxValue: 100).quantityRange(for: unit)
        expectedRanges[.workout] = DoubleRange(minValue: 110, maxValue: 130).quantityRange(for: unit)
        XCTAssertEqual(correctionRangeOverrides?.ranges, expectedRanges)
    }
}
